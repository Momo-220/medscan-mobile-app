"""
History Endpoints
User's scan and interaction history
"""

from fastapi import APIRouter, Depends, Query, status
from typing import Dict, Any, Optional
import structlog

from app.models.schemas import HistoryResponse, ScanHistoryItem
from app.services.auth_service import get_current_user, require_full_account
from app.services.scan_history_service import scan_history_service

logger = structlog.get_logger()

router = APIRouter()


@router.get("", response_model=HistoryResponse)
async def get_history(
    limit: int = Query(50, ge=1, le=100, description="Number of items to return"),
    page: int = Query(1, ge=1, description="Page number"),
    language: Optional[str] = Query(None, description="Target language code for history items translation"),
    user: Dict[str, Any] = Depends(require_full_account),
) -> HistoryResponse:
    """
    📚 Get scan history
    
    Retrieve your medication scan history.
    Results are ordered by most recent first.
    
    **Use cases:**
    - Review past scans
    - Track medication changes
    - Access previous analysis
    """
    
    user_id = user["uid"]
    logger.info("Retrieving scan history", user_id=user_id, limit=limit, page=page, language=language)
    
    # Calculate offset for pagination
    offset = (page - 1) * limit
    
    # Get history from PostgreSQL
    history_data = scan_history_service.get_user_history(
        user_id=user_id,
        limit=limit,
        offset=offset,
    )

    # Batch translate items using Gemini if target language is requested
    if language and history_data:
        target_lang_key = language.lower()
        items_to_translate = []
        
        # Apply cached translations and collect cache misses
        for item in history_data:
            db_translations = item.get("translations", {}) or {}
            orig_lang = item.get("packaging_language") or "fr"
            
            if target_lang_key == orig_lang.lower():
                continue
                
            if target_lang_key in db_translations and isinstance(db_translations[target_lang_key], dict) and "excipients" in db_translations[target_lang_key]:
                # Cache hit! Populate translation fields
                t_data = db_translations[target_lang_key]
                item["generic_name"] = t_data.get("generic_name") or item.get("generic_name")
                item["dosage"] = t_data.get("dosage") or item.get("dosage")
                item["form"] = t_data.get("form") or item.get("form")
                item["category"] = t_data.get("category") or item.get("category")
                
                is_full = isinstance(t_data, dict) and ("indications" in t_data or "side_effects" in t_data) and "excipients" in t_data
                
                # Update analysis_data nested fields
                analysis_data = item.get("analysis_data") or {}
                if isinstance(analysis_data, str):
                    try:
                        import json
                        analysis_data = json.loads(analysis_data)
                    except:
                        analysis_data = {}
                if isinstance(analysis_data, dict):
                    if is_full:
                        analysis_data.update(t_data)
                        analysis_data["packaging_language"] = language
                    else:
                        analysis_data["generic_name"] = t_data.get("generic_name") or analysis_data.get("generic_name")
                        analysis_data["dosage"] = t_data.get("dosage") or analysis_data.get("dosage")
                        analysis_data["form"] = t_data.get("form") or analysis_data.get("form")
                        analysis_data["category"] = t_data.get("category") or analysis_data.get("category")
                    item["analysis_data"] = analysis_data
                
                if is_full:
                    item["packaging_language"] = language
            else:
                # Cache miss! Add to batch translation list
                items_to_translate.append(item)
                
        if items_to_translate:
            try:
                from app.services.gemini_service import gemini_service
                translated_items = await gemini_service.translate_history_items(items_to_translate, language)
                
                # Save newly translated items back to DB cache
                for t_item in translated_items:
                    t_scan_id = t_item.get("scan_id") or t_item.get("id")
                    if t_scan_id:
                        orig_item = next((x for x in items_to_translate if (x.get("scan_id") or x.get("id")) == t_scan_id), None)
                        if orig_item:
                            db_translations = orig_item.get("translations", {}) or {}
                            db_translations[target_lang_key] = t_item.get("analysis_data") or {
                                "generic_name": t_item.get("generic_name"),
                                "dosage": t_item.get("dosage"),
                                "form": t_item.get("form"),
                                "category": t_item.get("category"),
                            }
                            # Update DB
                            scan_history_service.update_scan_translations(t_scan_id, db_translations)
                            
                            # Update local history_data item
                            for local_item in history_data:
                                if (local_item.get("scan_id") or local_item.get("id")) == t_scan_id:
                                    local_item["generic_name"] = t_item.get("generic_name")
                                    local_item["dosage"] = t_item.get("dosage")
                                    local_item["form"] = t_item.get("form")
                                    local_item["category"] = t_item.get("category")
                                    local_item["analysis_data"] = t_item.get("analysis_data")
                                    local_item["packaging_language"] = language
                                    local_item["translations"] = db_translations
            except Exception as e:
                logger.error("Error batch translating history items", error=str(e))
    
    # Get total count for pagination
    total_count = scan_history_service.get_scan_count(user_id)
    
    # Convert to response format with full data
    scans = []
    for item in history_data:
        # Extraire analysis_data si c'est une string JSON
        analysis_data = item.get("analysis_data")
        if isinstance(analysis_data, str):
            import json
            try:
                analysis_data = json.loads(analysis_data)
            except:
                analysis_data = {}
        
        scans.append(
            ScanHistoryItem(
                id=item.get("scan_id", item.get("id")),
                scan_id=item.get("scan_id", item.get("id")),
                medication_name=item.get("medication_name", "Unknown"),
                generic_name=analysis_data.get("generic_name") or item.get("generic_name") if analysis_data else item.get("generic_name"),
                dosage=analysis_data.get("dosage") or item.get("dosage") if analysis_data else item.get("dosage"),
                form=analysis_data.get("form") or item.get("form") if analysis_data else item.get("form"),
                category=analysis_data.get("category") or item.get("category", "Unknown") if analysis_data else item.get("category", "Unknown"),
                manufacturer=analysis_data.get("manufacturer") or item.get("manufacturer") if analysis_data else item.get("manufacturer"),
                packaging_language=analysis_data.get("packaging_language") or item.get("packaging_language") or "fr" if analysis_data else "fr",
                image_url=item.get("image_url"),
                confidence=item.get("confidence", "medium"),
                scanned_at=item.get("created_at"),
                analysis_data=analysis_data,
                warnings=item.get("warnings"),
                contraindications=item.get("contraindications"),
                interactions=item.get("interactions"),
                side_effects=item.get("side_effects"),
                disclaimer=analysis_data.get("disclaimer", "⚕️ Ceci est uniquement à titre informatif.") if analysis_data else "⚕️ Ceci est uniquement à titre informatif.",
            )
        )
    
    logger.info("History retrieved from MongoDB", 
                user_id=user_id, 
                count=len(scans),
                total=total_count)
    
    return HistoryResponse(
        scans=scans,
        count=len(scans),
        total=total_count,
        page=page,
        per_page=limit,
    )


@router.post("/migrate", status_code=status.HTTP_201_CREATED)
async def migrate_history_item(
    item: Dict[str, Any],
    user: Dict[str, Any] = Depends(require_full_account),
):
    """
    🚚 Migrate local/anonymous scan history item to MongoDB
    """
    user_id = user["uid"]
    logger.info("Migrating history item", user_id=user_id, medication=item.get("medication_name"))
    
    try:
        import uuid
        scan_id = item.get("scan_id") or item.get("id") or str(uuid.uuid4())
        
        scan_data = {
            "scan_id": scan_id,
            "medication_name": item.get("medication_name", "Unknown"),
            "generic_name": item.get("generic_name"),
            "dosage": item.get("dosage"),
            "form": item.get("form"),
            "manufacturer": item.get("manufacturer"),
            "image_url": item.get("image_url"),
            "confidence": item.get("confidence", "medium"),
            "warnings": item.get("warnings", []),
            "contraindications": item.get("contraindications", []),
            "interactions": item.get("interactions", []),
            "side_effects": item.get("side_effects", []),
            "analysis_data": item.get("analysis_data") or {},
            "packaging_language": item.get("packaging_language", "fr"),
            "category": item.get("category", "autre"),
        }
        
        saved_id = scan_history_service.save_scan(
            user_id=user_id,
            scan_data=scan_data,
        )
        return {"status": "success", "scan_id": saved_id}
    except Exception as e:
        logger.error("Failed to migrate scan to MongoDB", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to migrate scan: {str(e)}"
        )


@router.post("/translate")
async def translate_local_history(
    payload: Dict[str, Any],
    language: str = Query(..., description="Target language code"),
):
    """
    🌐 Translate a list of local/anonymous scan items
    """
    items = payload.get("items") or []
    if not items:
        return {"items": []}
        
    logger.info("Translating local history items", count=len(items), target_language=language)
    try:
        from app.services.gemini_service import gemini_service
        translated_items = await gemini_service.translate_history_items(items, language)
        return {"items": translated_items}
    except Exception as e:
        logger.error("Failed to translate local history items", error=str(e))
        return {"items": items}




