"""
Image storage - MongoDB GridFS (remplace GCS)
"""

from typing import Optional
import uuid
import os
import structlog
from bson import ObjectId
from gridfs import GridFS

from app.config import settings
from app.db.mongodb import get_db
from app.core.exceptions import ImageProcessingError

logger = structlog.get_logger()


class StorageService:
    """Store images in MongoDB GridFS"""

    def __init__(self):
        self._fs: Optional[GridFS] = None
        self._initialized = False

    async def initialize(self):
        if self._initialized:
            return
        try:
            db = get_db()
            self._fs = GridFS(db, collection="scan_images")
            self._initialized = True
            logger.info("Storage initialized (MongoDB GridFS)")
        except Exception as e:
            logger.error("Storage init failed", error=str(e))
            raise ImageProcessingError("Failed to initialize storage service")

    async def upload_image(
        self,
        image_bytes: bytes,
        user_id: str,
        content_type: str = "image/jpeg",
    ) -> str:
        try:
            if not self._fs:
                raise ImageProcessingError("Storage non configuré")

            file_id = self._fs.put(
                image_bytes,
                filename=f"scans/{user_id}/{uuid.uuid4()}.{content_type.split('/')[-1]}",
                content_type=content_type,
                metadata={"user_id": user_id},
            )
            base_url = (settings.API_PUBLIC_URL or os.getenv("API_PUBLIC_URL") or "").rstrip("/")
            if base_url:
                image_url = f"{base_url}/api/v1/images/{str(file_id)}"
            else:
                image_url = f"/api/v1/images/{str(file_id)}"
            logger.info("Image uploaded to GridFS", file_id=str(file_id), user_id=user_id)
            return image_url
        except Exception as e:
            logger.error("Image upload failed", error=str(e))
            raise ImageProcessingError(f"Failed to upload image: {str(e)}")

    async def get_signed_url(self, blob_name: str, expiration: int = 3600) -> str:
        base_url = (settings.API_PUBLIC_URL or "").rstrip("/")
        return f"{base_url}/api/v1/images/proxy?path={blob_name}"

    async def delete_image(self, blob_name: str) -> bool:
        try:
            if self._fs and ObjectId.is_valid(blob_name):
                self._fs.delete(ObjectId(blob_name))
                return True
            return False
        except Exception as e:
            logger.error("Failed to delete image", error=str(e))
            return False


storage_service = StorageService()
