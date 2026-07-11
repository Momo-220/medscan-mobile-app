"""
Medication Suggestions Endpoints
Get similar medications from local BDPM database (FREE - 0 tokens!)
"""

from fastapi import APIRouter, Query
from typing import Optional
import structlog
import asyncio

from app.models.schemas import SuggestionsResponse, MedicationSuggestionResponse
from app.services.medication_db_service import medication_db_service

logger = structlog.get_logger()

router = APIRouter()


@router.get("", response_model=SuggestionsResponse, status_code=200)
async def get_suggestions(
    category: str = Query(..., description="Category of the scanned medication"),
    language: str = Query("fr", description="Language detected on packaging"),
    medication_name: Optional[str] = Query(None, description="Name of the scanned medication"),
    generic_name: Optional[str] = Query(None, description="Generic name of the scanned medication"),
    indications: Optional[str] = Query(None, description="Therapeutic indications"),
    active_ingredient: Optional[str] = Query(None, description="Active ingredient"),
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
    
    logger.info("Fetching suggestions from local BDPM", category=category, limit=limit)
    
    try:
        # Utiliser la base de données locale (0 tokens Gemini!) dans un thread séparé
        suggestions = await asyncio.to_thread(
            medication_db_service.get_suggestions,
            category=category,
            limit=limit,
            exclude_name=medication_name,
            indications=indications,
            active_ingredient=active_ingredient
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
