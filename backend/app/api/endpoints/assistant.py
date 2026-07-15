"""
AI Assistant Endpoints
Conversational pharmaceutical guidance
"""

from fastapi import APIRouter, Depends, HTTPException, status, Body
from fastapi import Request
from fastapi.responses import StreamingResponse
from typing import Dict, Any
import structlog
import json

from app.models.schemas import ChatRequest, ChatResponse, ChatHistoryResponse, ChatMessage
from app.services.auth_service import get_current_user
from app.services.gemini_service import gemini_service
from app.services.firebase_service import firebase_service
from app.core.exceptions import AIServiceError
from app.services.credits_service import credits_service

logger = structlog.get_logger()

router = APIRouter()


@router.post("/chat", response_model=ChatResponse)
async def chat_with_assistant(
    request: ChatRequest = Body(...),
    user: Dict[str, Any] = Depends(get_current_user),
) -> ChatResponse:
    """
    💬 Chat with AI pharmaceutical assistant
    
    Ask questions about medications, interactions, side effects, or general pharmaceutical information.
    
    **The AI will:**
    - Answer medication questions
    - Explain drug interactions
    - Clarify usage instructions
    - Provide safety information
    
    **The AI cannot:**
    - Diagnose medical conditions
    - Prescribe medications
    - Replace your doctor or pharmacist
    - Provide emergency medical advice
    
    **Example questions:**
    - "Can I take ibuprofen with paracetamol?"
    - "What are the side effects of amoxicillin?"
    - "How should I store insulin?"
    """
    
    user_id = user["uid"]
    is_anonymous = user.get("is_anonymous", False)
    logger.info("Chat request received", user_id=user_id, message_length=len(request.message))
    
    # Get chat history if requested
    chat_history = []
    if request.include_history:
        try:
            history_data = await firebase_service.get_chat_history(user_id, limit=20)
            chat_history = [
                {
                    "role": msg.get("role", "user"),
                    "content": msg.get("content", ""),
                }
                for msg in history_data
            ]
        except Exception as e:
            logger.warning("Failed to load chat history", error=str(e))
            chat_history = []
    
    try:
        credits_service.ensure_credits(user_id, credits_service.CHAT_COST, is_anonymous=is_anonymous)

        # S'assurer que Gemini est initialisé
        if not gemini_service._initialized:
            logger.info("Initializing Gemini service for chat")
            await gemini_service.initialize()
        
        # 2) Generate AI response
        ai_response = await gemini_service.chat(
            message=request.message,
            chat_history=chat_history,
            language=request.language,
        )

        # 3) Consommer les crédits après succès basé sur les tokens réels
        tokens_used = 0
        if hasattr(ai_response, '_tokens_used'):
            tokens_used = ai_response._tokens_used
        
        if tokens_used > 0:
            credits_service.consume(user_id, credits_service.CHAT_COST, actual_tokens=tokens_used, is_anonymous=is_anonymous)
        else:
            credits_service.consume(user_id, credits_service.CHAT_COST, is_anonymous=is_anonymous)
        
        response_text = ai_response.text if hasattr(ai_response, 'text') else str(ai_response)
        message_id = None
        if not is_anonymous:
            try:
                await firebase_service.save_chat_message(
                    user_id=user_id,
                    message={
                        "role": "user",
                        "content": request.message,
                    },
                )
                
                message_id = await firebase_service.save_chat_message(
                    user_id=user_id,
                    message={"role": "assistant", "content": response_text},
                )
            except Exception as e:
                logger.warning("Failed to save chat message", error=str(e))
                message_id = None
        
        logger.info("Chat response generated", user_id=user_id, message_id=message_id)
        
        return ChatResponse(
            message=response_text,
            message_id=message_id,
        )
        
    except AIServiceError as e:
        error_str = str(e).lower()
        lang_key = (request.language or "fr").lower()[:2]
        
        # Dictionnaire de messages conviviaux traduits pour le chat
        error_messages = {
            "fr": {
                "quota": "Le service de discussion est temporairement surchargé. Réessayez dans quelques minutes.",
                "timeout": "La connexion avec l'IA a expiré. Veuillez renvoyer votre message.",
                "generic": "Le service de discussion est indisponible pour le moment. Veuillez réessayer."
            },
            "tr": {
                "quota": "Sohbet hizmeti geçici olarak aşırı yüklendi. Lütfen birkaç dakika sonra tekrar deneyin.",
                "timeout": "Yapay zeka bağlantısı zaman aşımına uğradı. Lütfen mesajınızı tekrar gönderin.",
                "generic": "Sohbet hizmeti şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin."
            },
            "en": {
                "quota": "The chat service is temporarily overloaded. Please try again in a few minutes.",
                "timeout": "The connection with the AI timed out. Please resend your message.",
                "generic": "The chat service is currently unavailable. Please try again."
            },
            "ar": {
                "quota": "خدمة الدردشة محملة بشكل زائد مؤقتاً. يرجى المحاولة مرة أخرى بعد بضع دقائق.",
                "timeout": "انتهت مهلة الاتصال بالذكاء الاصطناعي. يرجى إعادة إرسال رسالتك.",
                "generic": "خدمة الدردشة غير متوفرة حالياً. يرجى المحاولة مرة أخرى لاحقاً."
            }
        }
        
        msgs = error_messages.get(lang_key, error_messages["fr"])
        
        if "quota" in error_str or "429" in error_str or "surchargé" in error_str:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=msgs["quota"]
            )
        elif "timeout" in error_str or "timed out" in error_str or "connection" in error_str:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail=msgs["timeout"]
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=msgs["generic"]
            )
    except Exception as e:
        logger.exception("Chat failed", user_id=user_id, error=str(e))
        lang_key = (request.language or "fr").lower()[:2]
        generic_errors = {
            "fr": "Impossible de générer une réponse.",
            "tr": "Yanıt oluşturulamadı.",
            "en": "Failed to generate a response.",
            "ar": "تعذر إنشاء رد."
        }
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=generic_errors.get(lang_key, generic_errors["fr"]),
        )


@router.post("/chat/stream")
async def chat_with_assistant_stream(
    request: Request,
):
    """
    Chat with AI assistant (streaming)
    
    Same as /chat but streams the response in real-time for better UX.
    Responses come as Server-Sent Events (SSE).
    """
    # Authentification manuelle (car on utilise Request directement pour le streaming)
    auth_header = request.headers.get("authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token d'authentification requis"
        )
    token = auth_header.replace("Bearer ", "")
    from app.services.auth_service import _try_local_jwt
    
    user_data = _try_local_jwt(token)
    if not user_data:
        try:
            user_data = await firebase_service.verify_token(token)
        except Exception as e:
            logger.error("Stream auth failed", error=str(e))
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token invalide"
            )
            
    user_id = user_data["uid"]
    is_anonymous = user_data.get("is_anonymous", False)
    
    # Parser le body JSON
    try:
        body_bytes = await request.body()
        if not body_bytes:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Request body is required"
            )
        
        body = json.loads(body_bytes.decode('utf-8'))
        chat_request = ChatRequest(**body)
    except json.JSONDecodeError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid JSON: {str(e)}"
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Validation error: {str(e)}"
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid request body: {str(e)}"
        )
    
    logger.info("Streaming chat request", 
                user_id=user_id, 
                message_length=len(chat_request.message) if chat_request.message else 0,
                include_history=chat_request.include_history)
    
    # Validate request (Pydantic le fait déjà, mais on double-check)
    if not chat_request.message or not chat_request.message.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Message cannot be empty"
        )
    
    try:
        credits_service.ensure_credits(user_id, credits_service.CHAT_COST, is_anonymous=is_anonymous)
    except HTTPException:
        raise
    
    chat_history = []
    if chat_request.include_history:
        try:
            history_data = await firebase_service.get_chat_history(user_id, limit=20)
            chat_history = [
                {"role": msg.get("role", "user"), "content": msg.get("content", "")}
                for msg in history_data
            ]
        except Exception as e:
            logger.warning("Failed to load chat history for stream", error=str(e))
    
    async def generate():
        """Generate streaming response"""
        full_response = ""
        credits_consumed = False
        tokens_used = 0
        
        try:
            # S'assurer que Gemini est initialisé
            if not gemini_service._initialized:
                logger.info("Initializing Gemini service for chat")
                await gemini_service.initialize()
            
            async for chunk_text, chunk_tokens in gemini_service.chat_stream(chat_request.message, chat_history, chat_request.language):
                if chunk_text:
                    full_response += chunk_text
                    # Send as SSE format
                    yield f"data: {json.dumps({'chunk': chunk_text})}\n\n"
                
                # Le dernier chunk contient les tokens totaux
                if chunk_tokens > 0:
                    tokens_used = chunk_tokens
            
            if tokens_used > 0:
                credits_service.consume(user_id, credits_service.CHAT_COST, actual_tokens=tokens_used, is_anonymous=is_anonymous)
            else:
                credits_service.consume(user_id, credits_service.CHAT_COST, is_anonymous=is_anonymous)
            credits_consumed = True
            
            yield f"data: {json.dumps({'done': True})}\n\n"
            
            if not is_anonymous:
                try:
                    await firebase_service.save_chat_message(
                        user_id=user_id,
                        message={"role": "user", "content": chat_request.message},
                    )
                    await firebase_service.save_chat_message(
                        user_id=user_id,
                        message={"role": "assistant", "content": full_response},
                    )
                except Exception as e:
                    logger.warning("Failed to save stream messages", error=str(e))
            
        except AIServiceError as e:
            logger.error("Streaming chat failed - AI Service Error", error=str(e))
            error_str = str(e).lower()
            lang_key = (chat_request.language or "fr").lower()[:2]
            
            error_messages = {
                "fr": {
                    "quota": "Le service de discussion est temporairement surchargé. Réessayez dans quelques minutes.",
                    "timeout": "La connexion avec l'IA a expiré. Veuillez renvoyer votre message.",
                    "generic": "Le service de discussion est indisponible pour le moment. Veuillez réessayer."
                },
                "tr": {
                    "quota": "Sohbet hizmeti geçici olarak aşırı yüklendi. Lütfen birkaç dakika sonra tekrar deneyin.",
                    "timeout": "Yapay zeka bağlantısı zaman aşımına uğradı. Lütfen mesajınızı tekrar gönderin.",
                    "generic": "Sohbet hizmeti şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin."
                },
                "en": {
                    "quota": "The chat service is temporarily overloaded. Please try again in a few minutes.",
                    "timeout": "The connection with the AI timed out. Please resend your message.",
                    "generic": "The chat service is currently unavailable. Please try again."
                },
                "ar": {
                    "quota": "خدمة الدردشة محملة بشكل زائد مؤقتاً. يرجى المحاولة مرة أخرى بعد بضع دقائق.",
                    "timeout": "انتهت مهلة الاتصال بالذكاء الاصطناعي. يرجى إعادة إرسال رسالتك.",
                    "generic": "خدمة الدردشة غير متوفرة حالياً. يرجى المحاولة مرة أخرى لاحقاً."
                }
            }
            
            msgs = error_messages.get(lang_key, error_messages["fr"])
            detail = msgs["generic"]
            if "quota" in error_str or "429" in error_str or "surchargé" in error_str:
                detail = msgs["quota"]
            elif "timeout" in error_str or "timed out" in error_str or "connection" in error_str:
                detail = msgs["timeout"]
                
            yield f"data: {json.dumps({'error': detail})}\n\n"
        except HTTPException as e:
            if e.status_code == 402:
                yield f"data: {json.dumps({'error': 'INSUFFICIENT_CREDITS', 'status': 402})}\n\n"
            else:
                yield f"data: {json.dumps({'error': str(e.detail)})}\n\n"
        except Exception as e:
            logger.error("Streaming chat failed", error=str(e), exc_info=True)
            lang_key = (chat_request.language or "fr").lower()[:2]
            generic_errors = {
                "fr": "Impossible de générer une réponse.",
                "tr": "Yanıt oluşturulamadı.",
                "en": "Failed to generate a response.",
                "ar": "تعذر إنشاء رد."
            }
            yield f"data: {json.dumps({'error': generic_errors.get(lang_key, generic_errors['fr'])})}\n\n"
    
    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
    )


@router.get("/history", response_model=ChatHistoryResponse)
async def get_chat_history(
    limit: int = 100,
    user: Dict[str, Any] = Depends(get_current_user),
) -> ChatHistoryResponse:
    """
    📜 Get chat history
    
    Retrieve your conversation history with the AI assistant.
    """
    
    user_id = user["uid"]
    logger.info("Retrieving chat history", user_id=user_id, limit=limit)
    
    messages = []
    try:
            history_data = await firebase_service.get_chat_history(user_id, limit=limit)
            # Convert to ChatMessage objects
            messages = [
                ChatMessage(
                    role=msg.get("role", "user"),
                    content=msg.get("content", ""),
                    timestamp=msg.get("created_at"),
                )
                for msg in history_data
            ]
    except Exception as e:
        logger.warning("Failed to retrieve chat history", error=str(e))
        messages = []
    
    return ChatHistoryResponse(
        messages=messages,
        count=len(messages),
    )

