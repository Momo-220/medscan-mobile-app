"""
Image serving - Cloudflare R2 & MongoDB GridFS
"""
from fastapi import APIRouter, Response
from fastapi.responses import RedirectResponse
from bson import ObjectId
from gridfs import GridFS
import structlog

from app.db.mongodb import get_db
from app.services.storage_service import storage_service

logger = structlog.get_logger()
router = APIRouter()


@router.get("/{file_path:path}")
async def get_image(file_path: str):
    """
    Serve image by path or ID.
    1. If file_path starts with 'scans/' or contains '/', fetches directly from Cloudflare R2.
    2. Checks MongoDB GridFS if file_path is a valid 24-character ObjectId.
    3. Checks scan_history in database for matching records.
    """
    try:
        clean_path = file_path.lstrip('/')
        # 1. Cloudflare R2 direct stream (scans/...)
        if clean_path.startswith("scans/") or "/" in clean_path:
            try:
                await storage_service.initialize()
                if storage_service._r2_client and storage_service._r2_bucket:
                    obj = storage_service._r2_client.get_object(
                        Bucket=storage_service._r2_bucket,
                        Key=clean_path,
                    )
                    data = obj["Body"].read()
                    content_type = obj.get("ContentType") or "image/jpeg"
                    return Response(
                        content=data,
                        media_type=content_type,
                        headers={
                            "Cache-Control": "public, max-age=31536000, immutable",
                            "Access-Control-Allow-Origin": "*",
                        },
                    )
            except Exception as r2_err:
                logger.warning("R2 direct fetch failed, trying fallbacks", path=file_path, error=str(r2_err))

        db = get_db()

        # 2. Check GridFS if valid ObjectId
        if ObjectId.is_valid(file_path):
            try:
                fs = GridFS(db, collection="scan_images")
                grid_out = fs.get(ObjectId(file_path))
                if grid_out:
                    data = grid_out.read()
                    content_type = grid_out.content_type or "image/jpeg"
                    return Response(
                        content=data,
                        media_type=content_type,
                        headers={
                            "Cache-Control": "public, max-age=86400",
                            "Access-Control-Allow-Origin": "*",
                        },
                    )
            except Exception:
                pass

        # 3. Check scan_history in DB
        scan = db.scan_history.find_one(
            {"$or": [
                {"legacy_file_id": file_path},
                {"image_url": {"$regex": file_path}},
                {"scan_id": file_path},
            ]}
        )
        if scan and scan.get("image_url"):
            target_url = scan["image_url"]
            if target_url.startswith("http"):
                # If target URL is an R2 key disguised as URL, try fetching key
                if "r2.dev" in target_url or "r2.cloudflarestorage.com" in target_url:
                    parts = target_url.split("/scans/")
                    if len(parts) > 1:
                        r2_key = f"scans/{parts[1]}"
                        try:
                            await storage_service.initialize()
                            if storage_service._r2_client and storage_service._r2_bucket:
                                obj = storage_service._r2_client.get_object(
                                    Bucket=storage_service._r2_bucket,
                                    Key=r2_key,
                                )
                                data = obj["Body"].read()
                                content_type = obj.get("ContentType") or "image/jpeg"
                                return Response(
                                    content=data,
                                    media_type=content_type,
                                    headers={
                                        "Cache-Control": "public, max-age=31536000, immutable",
                                        "Access-Control-Allow-Origin": "*",
                                    },
                                )
                        except Exception:
                            pass
                return RedirectResponse(url=target_url, status_code=302)

        return Response(status_code=404, content="Image not found")

    except Exception as e:
        logger.error("Image get failed", file_path=file_path, error=str(e))
        return Response(status_code=500, content="Failed to load image")
