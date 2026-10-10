"""
Image storage - Cloudflare R2 (S3-compatible) with MongoDB GridFS fallback/backward compatibility
"""

from typing import Optional
import uuid
import os
import structlog
from bson import ObjectId
from gridfs import GridFS
import boto3
from botocore.config import Config as BotoConfig

from app.config import settings
from app.db.mongodb import get_db
from app.core.exceptions import ImageProcessingError

logger = structlog.get_logger()


class StorageService:
    """Store images in Cloudflare R2 with MongoDB GridFS fallback"""

    def __init__(self):
        self._fs: Optional[GridFS] = None
        self._r2_client = None
        self._r2_bucket: Optional[str] = None
        self._r2_public_url: Optional[str] = None
        self._initialized = False

    async def initialize(self):
        if self._initialized:
            return

        # 1. Initialize MongoDB GridFS (always available for legacy reads & fallback)
        try:
            db = get_db()
            self._fs = GridFS(db, collection="scan_images")
            logger.info("MongoDB GridFS initialized")
        except Exception as e:
            logger.warning("MongoDB GridFS init failed", error=str(e))

        # 2. Initialize Cloudflare R2 (Primary production storage)
        if settings.R2_ACCESS_KEY_ID and settings.R2_SECRET_ACCESS_KEY:
            try:
                endpoint = settings.r2_endpoint
                if endpoint:
                    self._r2_client = boto3.client(
                        "s3",
                        endpoint_url=endpoint,
                        aws_access_key_id=settings.R2_ACCESS_KEY_ID,
                        aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
                        region_name="auto",
                        config=BotoConfig(
                            signature_version="s3v4",
                            retries={"max_attempts": 3, "mode": "standard"},
                        ),
                    )
                    self._r2_bucket = settings.R2_BUCKET_NAME or "medscan-scans"
                    self._r2_public_url = (settings.R2_PUBLIC_URL or "").rstrip("/")
                    logger.info(
                        "Cloudflare R2 storage initialized",
                        bucket=self._r2_bucket,
                        public_url=self._r2_public_url,
                    )
            except Exception as e:
                logger.error("Cloudflare R2 init failed", error=str(e))

        if not self._r2_client and not self._fs:
            raise ImageProcessingError("No storage service available (neither R2 nor GridFS)")

        self._initialized = True
        logger.info(
            "StorageService ready",
            primary="Cloudflare R2" if self._r2_client else "MongoDB GridFS",
            r2_enabled=bool(self._r2_client),
            gridfs_enabled=bool(self._fs),
        )

    async def upload_image(
        self,
        image_bytes: bytes,
        user_id: str,
        content_type: str = "image/jpeg",
    ) -> str:
        """
        Upload an image. Uses Cloudflare R2 if available, otherwise GridFS.
        Returns the public image URL.
        """
        try:
            # Normalize extension
            ext = content_type.split("/")[-1].lower()
            if ext == "jpeg":
                ext = "jpg"

            # 1. Primary: Cloudflare R2
            if self._r2_client and self._r2_bucket:
                filename = f"scans/{user_id}/{uuid.uuid4()}.{ext}"
                self._r2_client.put_object(
                    Bucket=self._r2_bucket,
                    Key=filename,
                    Body=image_bytes,
                    ContentType=content_type,
                    CacheControl="public, max-age=31536000, immutable",
                )
                base_url = (settings.API_PUBLIC_URL or os.getenv("API_PUBLIC_URL") or "https://medscan-app-xx6a.onrender.com").rstrip("/")
                image_url = f"{base_url}/api/v1/images/{filename}"
                logger.info(
                    "Image uploaded to Cloudflare R2",
                    key=filename,
                    user_id=user_id,
                    url=image_url,
                )
                return image_url

            # 2. Fallback: MongoDB GridFS
            if self._fs:
                file_id = self._fs.put(
                    image_bytes,
                    filename=f"scans/{user_id}/{uuid.uuid4()}.{ext}",
                    content_type=content_type,
                    metadata={"user_id": user_id},
                )
                base_url = (settings.API_PUBLIC_URL or os.getenv("API_PUBLIC_URL") or "https://medscan-app-xx6a.onrender.com").rstrip("/")
                image_url = f"{base_url}/api/v1/images/{str(file_id)}"
                logger.info("Image uploaded to GridFS (fallback)", file_id=str(file_id), user_id=user_id)
                return image_url

            raise ImageProcessingError("Aucun service de stockage actif")

        except Exception as e:
            logger.error("Image upload failed", error=str(e))
            raise ImageProcessingError(f"Failed to upload image: {str(e)}")

    async def get_signed_url(self, blob_name: str, expiration: int = 3600) -> str:
        """Return URL or proxy URL for an image"""
        if self._r2_public_url and not blob_name.startswith("http"):
            return f"{self._r2_public_url}/{blob_name.lstrip('/')}"
        base_url = (settings.API_PUBLIC_URL or "").rstrip("/")
        return f"{base_url}/api/v1/images/proxy?path={blob_name}"

    async def delete_image(self, identifier: str) -> bool:
        """Delete image from R2 or GridFS"""
        deleted = False
        try:
            # If R2 URL or key
            if self._r2_client and self._r2_bucket:
                key = identifier
                if self._r2_public_url and identifier.startswith(self._r2_public_url):
                    key = identifier.replace(self._r2_public_url, "").lstrip("/")
                if key.startswith("scans/"):
                    self._r2_client.delete_object(Bucket=self._r2_bucket, Key=key)
                    logger.info("Image deleted from R2", key=key)
                    deleted = True

            # If ObjectId for GridFS
            if self._fs and ObjectId.is_valid(identifier):
                self._fs.delete(ObjectId(identifier))
                logger.info("Image deleted from GridFS", file_id=identifier)
                deleted = True

            return deleted
        except Exception as e:
            logger.error("Failed to delete image", identifier=identifier, error=str(e))
            return False


storage_service = StorageService()
