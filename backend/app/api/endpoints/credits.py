"""
Credits (Gemmes) Endpoints
Manage AI credits for Gemini usage
"""

from fastapi import APIRouter, Depends, HTTPException, status, Body, Request
from typing import Dict, Any
from datetime import datetime, timezone, timedelta
import structlog
import json

from app.models.schemas import CreditsResponse, CreditsUpdateRequest
from app.services.auth_service import get_current_user
from app.services.credits_service import credits_service


logger = structlog.get_logger()

router = APIRouter()


def _next_reset_utc() -> str:
    """Prochain renouvellement des gemmes : minuit UTC du lendemain."""
    now = datetime.now(timezone.utc)
    tomorrow = now.date() + timedelta(days=1)
    next_reset = datetime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0, 0, tzinfo=timezone.utc)
    return next_reset.isoformat()


@router.get("", response_model=CreditsResponse)
async def get_my_credits(
    user: Dict[str, Any] = Depends(get_current_user),
) -> CreditsResponse:
    """
    Get current AI credits (gemmes) for the authenticated user.
    Règle:
    - Compte inscrit : 30 gemmes/jour (reset quotidien).
    - Mode essai (anonyme) : pack unique (pas de reset quotidien).
    """
    user_id = user["uid"]
    is_anonymous = user.get("is_anonymous", False)
    credits_obj = credits_service.get_or_create(user_id, is_anonymous)
    credits = credits_obj.get("credits", 0)
    next_reset_at = None if is_anonymous else _next_reset_utc()
    logger.info("Credits retrieved", user_id=user_id, credits=credits, is_trial=is_anonymous)
    return CreditsResponse(credits=credits, next_reset_at=next_reset_at)


@router.post("/add", response_model=CreditsResponse)
async def add_credits(
    http_request: Request,
    user: Dict[str, Any] = Depends(get_current_user),
) -> CreditsResponse:
    """
    Add credits to the current user.
    Body: { "amount": 10 }
    """
    user_id = user["uid"]
    
    try:
        body = await http_request.json()
        amount = body.get("amount")
        
        if not amount or not isinstance(amount, int) or amount <= 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Le champ 'amount' doit être un entier supérieur à 0"
            )
        
        is_anonymous = user.get("is_anonymous", False)
        credits = credits_service.add_credits(user_id, amount, is_anonymous)
        logger.info("Credits added", user_id=user_id, amount=amount, total=credits)
        return CreditsResponse(credits=credits, next_reset_at=None if is_anonymous else _next_reset_utc())
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to add credits", user_id=user_id, error=str(e), exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erreur lors de l'ajout de crédits: {str(e)}"
        )

