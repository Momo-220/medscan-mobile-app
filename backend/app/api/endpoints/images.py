"""
Image serving - MongoDB GridFS
"""
from fastapi import APIRouter, Response
from fastapi.responses import RedirectResponse
from bson import ObjectId
from gridfs import GridFS
import structlog

from app.db.mongodb import get_db

logger = structlog.get_logger()
router = APIRouter()


@router.get("/{file_id}")
async def get_image(file_id: str):
    """
    Serve image by ID.
    1. First checks MongoDB GridFS (legacy/unmigrated).
    2. If not found in GridFS, checks if migrated to Cloudflare R2 and redirects.
    """
    try:
        if not ObjectId.is_valid(file_id):
            return Response(status_code=400, content="Invalid image id")

        db = get_db()
        fs = GridFS(db, collection="scan_images")

        # 1. Check GridFS
        try:
            grid_out = fs.get(ObjectId(file_id))
            if grid_out:
                data = grid_out.read()
                content_type = grid_out.content_type or "image/jpeg"
                return Response(
                    content=data,
                    media_type=content_type,
                    headers={"Cache-Control": "public, max-age=86400"},
                )
        except Exception:
            grid_out = None

        # 2. Check if migrated to R2 in scan_history
        scan = db.scan_history.find_one(
            {"$or": [
                {"legacy_file_id": file_id},
                {"image_url": {"$regex": file_id}},
            ]}
        )
        if scan and scan.get("image_url") and scan["image_url"].startswith("http"):
            # Redirect to Cloudflare R2 CDN URL
            return RedirectResponse(url=scan["image_url"], status_code=302)

        return Response(status_code=404, content="Image not found")

    except Exception as e:
        logger.error("Image get failed", file_id=file_id, error=str(e))
        return Response(status_code=500, content="Failed to load image")
