"""
Medication Suggestions Endpoints
Get similar medications from local BDPM database (FREE - 0 tokens!)
"""

from fastapi import APIRouter, Query, Request
from typing import Optional
import structlog
import asyncio
import re

from app.models.schemas import SuggestionsResponse, MedicationSuggestionResponse
from app.services.medication_db_service import medication_db_service
from app.core.limiter import limiter

logger = structlog.get_logger()

router = APIRouter()

# Allowed characters for medication-related text inputs (alphanumeric + accents + hyphens)
_SAFE_TEXT_RE = re.compile(r"[^\w\s\-',\.()/éèêëàâùûüîïôœæçÉÈÊËÀÂÙÛÜÎÏÔŒÆÇ]", re.UNICODE)


def _sanitize(value: Optional[str], max_len: int = 200) -> Optional[str]:
    """Strip dangerous characters from free-text query parameters."""
    if value is None:
        return None
    value = value[:max_len]
    return _SAFE_TEXT_RE.sub("", value).strip() or None


@router.get("", response_model=SuggestionsResponse, status_code=200)
@limiter.limit("30/minute")
async def get_suggestions(
    request: Request,
    category: str = Query(..., description="Category of the scanned medication", max_length=100),
    language: str = Query("fr", description="Language detected on packaging", max_length=5),
    medication_name: Optional[str] = Query(None, description="Name of the scanned medication", max_length=200),
    generic_name: Optional[str] = Query(None, description="Generic name of the scanned medication", max_length=200),
    indications: Optional[str] = Query(None, description="Therapeutic indications", max_length=500),
    active_ingredient: Optional[str] = Query(None, description="Active ingredient", max_length=200),
    limit: int = Query(50, ge=1, le=100, description="Maximum number of suggestions (default 50, max 100)"),
) -> SuggestionsResponse:
    """
    Get medication suggestions from local BDPM database (FREE - 0 Gemini tokens!)

    🚀 ULTRA-PERFORMANT avec index O(1)
    - 20,000+ médicaments dans la base BDPM
    - Recherche instantanée (< 10ms)
    - Pas d'image requise, juste nom + caractéristiques
    - Jusqu'à 100 suggestions par requête
    - 0 coût API, 0 tokens Gemini
    """
    # Sanitize all free-text inputs to strip dangerous characters
    safe_category = _sanitize(category, max_len=100) or ""
    safe_medication_name = _sanitize(medication_name)
    safe_indications = _sanitize(indications, max_len=500)
    safe_active_ingredient = _sanitize(active_ingredient)

    logger.info("Fetching suggestions from local BDPM", category=safe_category, limit=limit)

    try:
        # Utiliser la base de données locale (0 tokens Gemini!) dans un thread séparé
        suggestions = await asyncio.to_thread(
            medication_db_service.get_suggestions,
            category=safe_category,
            limit=limit,
            exclude_name=safe_medication_name,
            indications=safe_indications,
            active_ingredient=safe_active_ingredient,
        )

        logger.info("Local DB suggestions fetched", count=len(suggestions))

        # Convertir au format API
        suggestion_responses = [
            MedicationSuggestionResponse(
                id=sug['id'],
                name=sug['name'],
                generic_name=sug['name'],
                brand_name=None,
                category=sug['category'],
                dosage=None,
                form=sug['form'],
                image_url=None,
                manufacturer=None,
                indications=f"Médicament de la catégorie {sug['category']}"
            )
            for sug in suggestions
        ]

        return SuggestionsResponse(
            suggestions=suggestion_responses,
            count=len(suggestion_responses)
        )

    except Exception as e:
        logger.error("Failed to fetch suggestions", error=str(e), exc_info=True)
        # Fallback vide si erreur
        return SuggestionsResponse(suggestions=[], count=0)
