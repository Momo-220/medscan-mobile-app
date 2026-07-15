"""
Medication Scan Endpoints
Upload and analyze medication images
"""

from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status, Query
from typing import Dict, Any, Optional
from datetime import datetime
import asyncio
import structlog

from app.models.schemas import ScanResponse
from app.services.auth_service import get_current_user
from app.services.gemini_service import gemini_service
from app.services.storage_service import storage_service
from app.services.scan_history_service import scan_history_service
from app.core.exceptions import ImageProcessingError, AIServiceError
from app.core.gemini_quota import check_and_increment as check_gemini_quota
from app.services.credits_service import credits_service

logger = structlog.get_logger()

router = APIRouter()


@router.post("", response_model=ScanResponse, status_code=status.HTTP_200_OK)
async def scan_medication(
    file: UploadFile = File(..., description="Medication image (JPEG/PNG, max 10MB)"),
    language: str = Query("fr", description="User language preference (fr/en)"),
    user: Dict[str, Any] = Depends(get_current_user),
) -> ScanResponse:
    """
    🔬 Analyze medication image using AI
    
    Upload a clear photo of your medication packaging or pills.
    Our AI will identify the medication and provide safety information.
    
    **Requirements:**
    - Image format: JPEG, PNG, WebP, GIF, BMP, TIFF, SVG
    - Max size: 10MB
    - Clear, well-lit photo
    - Visible medication name or packaging
    
    **Returns:**
    - Medication identification
    - Dosage and usage instructions
    - Warnings and contraindications
    - Drug interactions
    """
    
    user_id = user["uid"]
    is_anonymous = user.get("is_anonymous", False)
    
    # Validate file is provided
    if not file:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No file provided"
        )
    
    logger.info("Medication scan requested", 
                user_id=user_id, 
                filename=file.filename, 
                content_type=file.content_type,
                file_size=file.size if hasattr(file, 'size') else 'unknown')
    
    # VERY LENIENT validation - accept ANY image type or common image extensions
    # This should work for 99% of image files
    is_valid = False
    image_bytes_peek = None
    
    # Method 1: Check if content_type starts with "image/"
    if file.content_type and file.content_type.startswith("image/"):
        is_valid = True
        logger.info("File validated by content_type", content_type=file.content_type)
    
    # Method 2: If no content_type or validation failed, check file extension
    if not is_valid and file.filename:
        ext = file.filename.lower().split('.')[-1] if '.' in file.filename else ''
        allowed_extensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tiff', 'tif', 'svg', 'heic', 'heif', 'ico']
        if ext in allowed_extensions:
            is_valid = True
            logger.info("File validated by extension", extension=ext, filename=file.filename)
    
    # Method 3: If still not valid, try to read first bytes to detect image
    if not is_valid:
        try:
            # Read first few bytes to check magic numbers
            image_bytes_peek = await file.read(12)
            
            # Check for common image magic numbers
            if image_bytes_peek and len(image_bytes_peek) >= 4:
                if image_bytes_peek.startswith(b'\xFF\xD8\xFF'):  # JPEG
                    is_valid = True
                elif image_bytes_peek.startswith(b'\x89PNG'):  # PNG
                    is_valid = True
                elif image_bytes_peek.startswith(b'GIF'):  # GIF
                    is_valid = True
                elif image_bytes_peek.startswith(b'RIFF') and b'WEBP' in image_bytes_peek:  # WebP
                    is_valid = True
                elif image_bytes_peek.startswith(b'BM'):  # BMP
                    is_valid = True
                elif image_bytes_peek.startswith(b'\x00\x00\x01\x00') or image_bytes_peek.startswith(b'\x00\x00\x02\x00'):  # ICO
                    is_valid = True
            
            if is_valid:
                logger.info("File validated by magic number detection")
        except Exception as e:
            logger.warning("Could not validate by magic number", error=str(e))
            image_bytes_peek = None
            # If we can't validate, but it has image extension, accept it anyway
            if file.filename:
                ext = file.filename.lower().split('.')[-1] if '.' in file.filename else ''
                if ext in ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tiff', 'tif', 'svg', 'heic', 'heif', 'ico']:
                    is_valid = True
                    logger.info("File accepted by extension as fallback", extension=ext)
    
    # Final check - if still not valid, reject
    if not is_valid:
        logger.error("Invalid file type rejected", 
                    content_type=file.content_type, 
                    filename=file.filename,
                    file_size=file.size if hasattr(file, 'size') else 'unknown')
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Le fichier n'est pas une image valide. Type détecté : {file.content_type or 'inconnu'}, Fichier : {file.filename or 'sans nom'}"
        )
    
    # Read file
    try:
        # If we already read some bytes for validation, read the rest
        # Otherwise read the full file
        if image_bytes_peek and len(image_bytes_peek) > 0:
            # We already read 12 bytes, read the rest
            remaining = await file.read()
            image_bytes = image_bytes_peek + remaining
            logger.debug("File read with peek bytes", total_size=len(image_bytes))
        else:
            # Read full file from start
            image_bytes = await file.read()
            logger.debug("File read completely", size=len(image_bytes))
        
        if not image_bytes or len(image_bytes) == 0:
            raise ImageProcessingError("Le fichier est vide")
            
    except ImageProcessingError:
        raise
    except Exception as e:
        logger.error("Failed to read uploaded file", error=str(e), error_type=type(e).__name__)
        raise ImageProcessingError(f"Impossible de lire le fichier : {str(e)}")
    
    # Validate file size (max 10MB)
    if len(image_bytes) > 10 * 1024 * 1024:
        raise ImageProcessingError("Image too large. Maximum size is 10MB.")
    
    try:
        # 0. Vérifier les crédits disponibles (toujours, même en mode dev)
        credits_service.ensure_credits(user_id, credits_service.SCAN_COST, is_anonymous=is_anonymous)

        # 1. Ensure Gemini is initialized before analysis
        # Réinitialiser si nécessaire (pour prendre en compte une nouvelle clé API)
        if not gemini_service._initialized or not gemini_service.vision_model:
            logger.info("Initializing Gemini service before analysis")
            # Réinitialiser complètement pour prendre en compte une nouvelle clé API
            await gemini_service.initialize(force_reinit=True)
        
        # 2. Vérifier la limite globale quotidienne (éviter dépassement quota Gemini)
        if not check_gemini_quota():
            logger.warning("Daily scan limit reached, rejecting request", user_id=user_id)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Service temporairement surchargé. Réessayez demain.",
            )
        
        # 3. Run Gemini analysis and GridFS image storage upload in parallel
        logger.info("Starting Gemini analysis and Image storage upload concurrently...", user_id=user_id)
        
        async def upload_image_task():
            try:
                await storage_service.initialize()
                return await storage_service.upload_image(
                    image_bytes=image_bytes,
                    user_id=user_id,
                    content_type=file.content_type or "image/jpeg",
                )
            except Exception as e:
                logger.warning("Image upload failed (continuing without image URL)", error=str(e), user_id=user_id)
                return None

        try:
            # Create concurrent coroutines
            analysis_coro = gemini_service.analyze_medication_image(
                image_bytes=image_bytes,
                mime_type=file.content_type or "image/jpeg",
                user_language=language,
            )
            
            # Execute both in parallel
            analysis, image_url = await asyncio.gather(analysis_coro, upload_image_task())
            

            logger.info("Gemini analysis and image upload successful", 
                       medication=analysis.get("medication_name"),
                       category=analysis.get("category"),
                       confidence=analysis.get("confidence"),
                       has_image_url=bool(image_url))
        except AIServiceError as e:
            error_str = str(e).lower()
            lang_key = (language or "fr").lower()[:2]
            
            # Dictionnaire de messages conviviaux traduits
            error_messages = {
                "fr": {
                    "quota": "Le service est temporairement surchargé. Réessayez dans quelques minutes.",
                    "timeout": "L'analyse réseau a expiré. Veuillez reprendre une photo et réessayer.",
                    "generic": "Impossible de lire le médicament sur cette photo. Assurez-vous que l'image est nette, bien éclairée, et réessayez."
                },
                "tr": {
                    "quota": "Hizmet geçici olarak aşırı yüklendi. Lütfen birkaç dakika sonra tekrar deneyin.",
                    "timeout": "Ağ analizi zaman aşımına uğradı. Lütfen yeni bir fotoğraf çekip tekrar deneyin.",
                    "generic": "Bu fotoğraftaki ilaç okunamadı. Lütfen fotoğrafın net ve iyi aydınlatılmış olduğundan emin olup tekrar deneyin."
                },
                "en": {
                    "quota": "The service is temporarily overloaded. Please try again in a few minutes.",
                    "timeout": "Network analysis timed out. Please take a new photo and try again.",
                    "generic": "Could not identify the medication from this photo. Please make sure the image is clear and well-lit, then try again."
                },
                "ar": {
                    "quota": "الخدمة محملة بشكل زائد مؤقتاً. يرجى المحاولة مرة أخرى بعد بضع دقائق.",
                    "timeout": "انتهت مهلة تحليل الشبكة. يرجى التقاط صورة جديدة والمحاولة مرة أخرى.",
                    "generic": "تعذر التعرف على الدواء من هذه الصورة. يرجى التأكد من أن الصورة واضحة ومضاءة جيداً، ثم حاول مرة أخرى."
                }
            }
            
            # Fallback vers le français si la langue n'est pas supportée
            msgs = error_messages.get(lang_key, error_messages["fr"])
            
            if "quota" in error_str or "429" in error_str or "surchargé" in error_str:
                logger.error("Gemini quota exceeded during scan", error=str(e))
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=msgs["quota"]
                )
            elif "timeout" in error_str or "timed out" in error_str or "connection" in error_str:
                logger.error("Gemini timeout during scan", error=str(e))
                raise HTTPException(
                    status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                    detail=msgs["timeout"]
                )
            else:
                logger.error("Gemini analysis failed", error=str(e))
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=msgs["generic"]
                )
        
        # 4. Build response - Notice pharmaceutique complète
        # CRITIQUE : S'assurer que packaging_language et category ont TOUJOURS des valeurs
        # même si l'analyse a échoué, pour permettre les suggestions
        
        # Garantir packaging_language
        packaging_language = analysis.get("packaging_language")
        if not packaging_language or packaging_language.strip() == "":
            # Détection basique depuis le nom du fichier ou contenu
            if file.filename:
                filename_lower = file.filename.lower()
                if any(ext in filename_lower for ext in [".fr", "_fr", "french"]):
                    packaging_language = "fr"
                elif any(ext in filename_lower for ext in [".en", "_en", "english"]):
                    packaging_language = "en"
                else:
                    packaging_language = "fr"  # Par défaut français
            else:
                packaging_language = "fr"  # Par défaut français
            logger.info("Set default packaging_language", language=packaging_language)
        
        # Garantir category - TOUJOURS utiliser "antidouleur" au lieu de "autre" pour permettre les suggestions
        category = analysis.get("category")
        if not category or category.strip() == "" or category.lower() == "autre":
            # Essayer de deviner depuis le nom du médicament
            medication_name_lower = (analysis.get("medication_name", "") or "").lower()
            generic_name_lower = (analysis.get("generic_name", "") or "").lower()
            active_ingredient_lower = (analysis.get("active_ingredient", "") or "").lower()
            indications_lower = (analysis.get("indications", "") or "").lower()
            
            # Détection basique de catégorie
            if any(term in medication_name_lower or term in generic_name_lower or term in active_ingredient_lower or term in indications_lower
                   for term in ["paracétamol", "acetaminophen", "paracetamol", "ibuprofen", "aspirin", "aspirine", "diclofenac", "doliprane", "efferalgan", "dafalgan", "advil"]):
                category = "antidouleur"
            elif any(term in medication_name_lower or term in generic_name_lower or term in active_ingredient_lower or term in indications_lower
                     for term in ["amoxicillin", "amoxicilline", "penicillin", "pénicilline", "augmentin", "clamoxyl", "antibiotic", "antibiotique"]):
                category = "antibiotique"
            elif any(term in medication_name_lower or term in generic_name_lower or term in active_ingredient_lower or term in indications_lower
                     for term in ["cétirizine", "cetirizine", "loratadine", "zyrtec", "claritin", "antihistaminique", "antihistaminic"]):
                category = "antihistaminique"
            else:
                category = "antidouleur"  # Par défaut antidouleur pour permettre les suggestions
            logger.info("Set default category", category=category)
        
        # Mettre à jour l'analysis avec les valeurs garanties
        analysis["packaging_language"] = packaging_language
        analysis["category"] = category
        
        # 5. Save to PostgreSQL (replaces Firestore)
        logger.info("Saving scan to MongoDB", user_id=user_id)
        import uuid
        scan_id = str(uuid.uuid4())
        
        scan_data = {
            "scan_id": scan_id,
            "medication_name": analysis.get("medication_name", "Unknown"),
            "generic_name": analysis.get("generic_name"),
            "dosage": analysis.get("dosage"),
            "form": analysis.get("form"),
            "manufacturer": analysis.get("manufacturer"),
            "image_url": image_url,
            "confidence": analysis.get("confidence", "low"),
            "warnings": analysis.get("warnings", []),
            "contraindications": analysis.get("contraindications", []),
            "interactions": analysis.get("interactions", []),
            "side_effects": analysis.get("side_effects", []),
            "analysis_data": analysis,  # Store full analysis
            "packaging_language": packaging_language,
            "category": category,
        }
        
        try:
            saved_scan_id = scan_history_service.save_scan(
                user_id=user_id,
                scan_data=scan_data,
            )
            scan_id = saved_scan_id
            logger.info("Scan saved to MongoDB", scan_id=scan_id)
        except Exception as e:
            logger.error("Failed to save scan to MongoDB", error=str(e))
        
        # 6. Consommer les crédits seulement si identification réussie (pas si "Médicament non identifié")
        med_name = (analysis.get("medication_name") or "").strip()
        confidence = (analysis.get("confidence") or "low").lower()
        med_name_lower = med_name.lower()
        identification_failed = (
            not med_name
            or med_name_lower in ("unknown", "médicament non identifié", "non identifié", "not identified", "inconnu", "aucun", "non détecté", "not detected")
            or "non identifié" in med_name_lower
            or "not identified" in med_name_lower
            or "inconnu" in med_name_lower
            or "non détecté" in med_name_lower
            or confidence == "low"
        )
        if not identification_failed:
            credits_service.consume(user_id, credits_service.SCAN_COST, is_anonymous=is_anonymous)
            logger.info("Credits consumed (fixed cost)", cost=credits_service.SCAN_COST, user_id=user_id)
        else:
            logger.info("Identification failed, credits NOT consumed", medication=med_name, confidence=confidence, user_id=user_id)

        # 7. Build response - Notice pharmaceutique complète
        # Helper function pour convertir les listes en strings
        def to_string(value, default=""):
            if value is None:
                return default
            if isinstance(value, list):
                return "\n".join(str(item) for item in value) if value else default
            return str(value)
        
        # Convertir les listes en strings pour les champs qui doivent être des strings
        contraindications_str = to_string(analysis.get("contraindications"))
        side_effects_str = to_string(analysis.get("side_effects"))
        interactions_str = to_string(analysis.get("interactions"))
        
        # Convertir dosage_instructions si nécessaire
        dosage_instructions_str = to_string(analysis.get("posology") or analysis.get("usage_instructions") or analysis.get("dosage_instructions"))
        
        response = ScanResponse(
                scan_id=scan_id,
                medication_name=analysis.get("medication_name", "Médicament non identifié"),
                generic_name=analysis.get("generic_name"),
                brand_name=analysis.get("brand_name"),
                dosage=analysis.get("dosage"),
                form=analysis.get("form"),
                category=category,
                active_ingredient=analysis.get("active_ingredient"),
                excipients=analysis.get("excipients"),
                indications=analysis.get("indications"),
                contraindications=contraindications_str,
                side_effects=side_effects_str,
                dosage_instructions=dosage_instructions_str,
                posology=analysis.get("posology") or analysis.get("usage_instructions"),
                precautions=analysis.get("precautions"),
                interactions=interactions_str,
                overdose=analysis.get("overdose"),
                storage=analysis.get("storage"),
                additional_info=analysis.get("additional_info"),
                manufacturer=analysis.get("manufacturer"),
                lot_number=analysis.get("lot_number"),
                expiry_date=analysis.get("expiry_date"),
                packaging_language=packaging_language,
                image_url=image_url,
                confidence=analysis.get("confidence", "low"),
                disclaimer=analysis.get("disclaimer"),
                warnings=analysis.get("warnings", []),
                analysis_data=analysis,
                analyzed_at=datetime.utcnow().isoformat(),
            )
        
        logger.info(
            "Scan completed successfully",
            user_id=user_id,
            scan_id=scan_id,
            category=response.category,
            packaging_language=response.packaging_language,
            medication=response.medication_name,
        )
        
        return response
        
    except (ImageProcessingError, AIServiceError, HTTPException):
        # Re-raise these exceptions as-is (already properly formatted)
        raise
    except Exception as e:
        # Log the full exception with traceback for debugging
        import traceback
        from tenacity import RetryError
        
        error_traceback = traceback.format_exc()
        error_type = type(e).__name__
        error_str = str(e)
        
        # Extraire le message d'erreur réel depuis RetryError
        if isinstance(e, RetryError):
            # RetryError encapsule l'erreur réelle dans last_attempt
            if hasattr(e, 'last_attempt') and e.last_attempt:
                last_exception = e.last_attempt.exception()
                if last_exception:
                    error_str = str(last_exception)
                    error_type = type(last_exception).__name__
                    # Si c'est une AIServiceError, utiliser son message
                    if isinstance(last_exception, AIServiceError):
                        error_str = str(last_exception)
        
        logger.exception("Scan failed unexpectedly", 
                        user_id=user_id, 
                        error=error_str,
                        error_type=error_type,
                        traceback=error_traceback)
        
        # Provide more detailed error message
        error_detail = f"Erreur lors de l'analyse: {error_str}"
        if "GEMINI_API_KEY" in error_str or "api key" in error_str.lower() or "n'est pas configurée" in error_str:
            error_detail = "Clé API Gemini non configurée ou invalide. Veuillez configurer GEMINI_API_KEY dans backend/.env et redémarrer le serveur."
        elif "quota" in error_str.lower() or "429" in error_str or "surchargé" in error_str.lower():
            error_detail = "Service temporairement surchargé. Réessayez dans quelques minutes."
        elif "invalid" in error_str.lower() and "api" in error_str.lower():
            error_detail = "Clé API Gemini invalide. Vérifiez que votre clé API est correcte dans backend/.env et redémarrez le serveur."
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=error_detail,
        )


@router.get("/{scan_id}", response_model=ScanResponse)
async def get_scan(
    scan_id: str,
    language: Optional[str] = Query(None, description="Optional target language for dynamic translation"),
    user: Dict[str, Any] = Depends(get_current_user),
) -> ScanResponse:
    """
    📋 Retrieve a previous scan by ID
    
    Get detailed information about a previously scanned medication.
    """
    
    user_id = user["uid"]
    logger.info("Retrieving scan from MongoDB", user_id=user_id, scan_id=scan_id, language=language)
    
    # Get scan from MongoDB
    scan_data = scan_history_service.get_scan_by_id(scan_id, user_id)
    
    if not scan_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scan not found",
        )
    
    # Build response
    analysis = scan_data.get("analysis_data", {})
    if not isinstance(analysis, dict):
        analysis = {}

    db_translations = scan_data.get("translations", {}) or {}


    def to_string(value, default=""):
        if value is None:
            return default
        if isinstance(value, list):
            return "\n".join(str(item) for item in value) if value else default
        return str(value)

    # Convert lists to strings where expected by the schema
    contraindications_str = to_string(analysis.get("contraindications") or scan_data.get("contraindications"))
    side_effects_str = to_string(analysis.get("side_effects") or scan_data.get("side_effects"))
    interactions_str = to_string(analysis.get("interactions") or scan_data.get("interactions"))
    dosage_instructions_str = to_string(analysis.get("posology") or analysis.get("usage_instructions") or analysis.get("dosage_instructions"))

    response = ScanResponse(
        scan_id=scan_id,
        medication_name=scan_data.get("medication_name", "Unknown"),
        generic_name=analysis.get("generic_name") or scan_data.get("generic_name"),
        brand_name=analysis.get("brand_name") or scan_data.get("brand_name"),
        dosage=analysis.get("dosage") or scan_data.get("dosage"),
        form=analysis.get("form") or scan_data.get("form"),
        category=analysis.get("category") or scan_data.get("category", "antidouleur"),
        active_ingredient=analysis.get("active_ingredient") or scan_data.get("active_ingredient"),
        excipients=analysis.get("excipients") or scan_data.get("excipients"),
        indications=analysis.get("indications") or scan_data.get("indications"),
        contraindications=contraindications_str,
        side_effects=side_effects_str,
        dosage_instructions=dosage_instructions_str,
        posology=analysis.get("posology") or analysis.get("usage_instructions"),
        precautions=analysis.get("precautions") or scan_data.get("precautions"),
        interactions=interactions_str,
        overdose=analysis.get("overdose") or scan_data.get("overdose"),
        storage=analysis.get("storage") or scan_data.get("storage"),
        additional_info=analysis.get("additional_info") or scan_data.get("additional_info"),
        manufacturer=analysis.get("manufacturer") or scan_data.get("manufacturer"),
        lot_number=analysis.get("lot_number") or scan_data.get("lot_number"),
        expiry_date=analysis.get("expiry_date") or scan_data.get("expiry_date"),
        packaging_language=analysis.get("packaging_language") or scan_data.get("packaging_language", "fr"),
        image_url=scan_data.get("image_url"),
        confidence=scan_data.get("confidence", "low"),
        disclaimer=analysis.get("disclaimer", "⚕️ This is for informational purposes only."),
        warnings=scan_data.get("warnings", []),
        analysis_data=analysis,
        scanned_at=scan_data.get("scanned_at") or datetime.utcnow(),
        analyzed_at=scan_data.get("analyzed_at") or datetime.utcnow().isoformat(),
    )
    
    return response
