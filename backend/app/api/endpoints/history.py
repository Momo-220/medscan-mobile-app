"""
History Endpoints
User's scan and interaction history
"""

from fastapi import APIRouter, Depends, Query, status
from typing import Dict, Any
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
    logger.info("Retrieving scan history", user_id=user_id, limit=limit, page=page)
    
    # Calculate offset for pagination
    offset = (page - 1) * limit
    
    # Get history from PostgreSQL
    history_data = scan_history_service.get_user_history(
        user_id=user_id,
        limit=limit,
        offset=offset,
    )


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


