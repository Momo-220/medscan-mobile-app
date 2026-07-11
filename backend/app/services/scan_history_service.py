"""
Scan History Service
Manages medication scan history in MongoDB
"""

from typing import List, Dict, Any, Optional
import structlog
import uuid
from datetime import datetime

from app.db.mongodb import get_collection
from app.core.exceptions import DatabaseError

logger = structlog.get_logger()

COLLECTION = "scan_history"


class ScanHistoryService:
    """Service for managing scan history in MongoDB"""

    MAX_SCANS_PER_USER = 50

    @staticmethod
    def _cleanup_old_scans(user_id: str) -> int:
        coll = get_collection(COLLECTION)
        count = coll.count_documents({"user_id": user_id})
        if count < ScanHistoryService.MAX_SCANS_PER_USER:
            return 0
        # Garder les N plus récents
        to_keep = (
            coll.find({"user_id": user_id})
            .sort("created_at", -1)
            .limit(ScanHistoryService.MAX_SCANS_PER_USER - 1)
        )
        keep_ids = [d["_id"] for d in to_keep]
        result = coll.delete_many(
            {"user_id": user_id, "_id": {"$nin": keep_ids}}
        )
        if result.deleted_count > 0:
            logger.info("Cleaned up old scans", user_id=user_id, deleted=result.deleted_count)
        return result.deleted_count

    @staticmethod
    def save_scan(user_id: str, scan_data: Dict[str, Any]) -> str:
        scan_id = scan_data.get("scan_id") or str(uuid.uuid4())
        try:
            coll = get_collection(COLLECTION)
            ScanHistoryService._cleanup_old_scans(user_id)

            now = datetime.utcnow()
            doc = {
                "user_id": user_id,
                "scan_id": scan_id,
                "medication_name": scan_data.get("medication_name", "Unknown"),
                "generic_name": scan_data.get("generic_name"),
                "dosage": scan_data.get("dosage"),
                "form": scan_data.get("form"),
                "manufacturer": scan_data.get("manufacturer"),
                "confidence": scan_data.get("confidence", "low"),
                "analysis_data": scan_data.get("analysis_data", {}),
                "warnings": scan_data.get("warnings", []),
                "contraindications": scan_data.get("contraindications", []),
                "interactions": scan_data.get("interactions", []),
                "side_effects": scan_data.get("side_effects", []),
                "image_url": scan_data.get("image_url"),
                "packaging_language": scan_data.get("packaging_language", "fr"),
                "category": scan_data.get("category", "autre"),
                "created_at": now,
                "updated_at": now,
            }
            existing = coll.find_one({"scan_id": scan_id})
            if existing:
                coll.update_one(
                    {"scan_id": scan_id},
                    {"$set": {**doc, "updated_at": now}},
                )
                logger.warning("Scan ID already exists, updated", scan_id=scan_id)
            else:
                coll.insert_one(doc)
                logger.info("Scan saved to MongoDB", user_id=user_id, scan_id=scan_id, medication=doc["medication_name"])
            return scan_id
        except Exception as e:
            logger.error("Failed to save scan", error=str(e))
            raise DatabaseError(f"Failed to save scan history: {str(e)}")

    @staticmethod
    def get_user_history(user_id: str, limit: int = 50, offset: int = 0) -> List[Dict[str, Any]]:
        try:
            coll = get_collection(COLLECTION)
            cursor = (
                coll.find({"user_id": user_id})
                .sort("created_at", -1)
                .skip(offset)
                .limit(limit)
            )
            history = []
            for d in cursor:
                d["id"] = str(d.get("_id"))
                history.append(_doc_to_scan_dict(d))
            logger.info("Retrieved user history", user_id=user_id, count=len(history))
            return history
        except Exception as e:
            logger.error("Failed to get user history", error=str(e))
            raise DatabaseError(f"Failed to retrieve scan history: {str(e)}")

    @staticmethod
    def get_scan_by_id(scan_id: str, user_id: Optional[str] = None) -> Optional[Dict[str, Any]]:
        try:
            coll = get_collection(COLLECTION)
            q = {"scan_id": scan_id}
            if user_id:
                q["user_id"] = user_id
            d = coll.find_one(q)
            if not d:
                return None
            d["id"] = str(d.get("_id"))
            return _doc_to_scan_dict(d)
        except Exception as e:
            logger.error("Failed to get scan", scan_id=scan_id, error=str(e))
            return None

    @staticmethod
    def delete_scan(scan_id: str, user_id: str) -> bool:
        try:
            coll = get_collection(COLLECTION)
            result = coll.delete_one({"scan_id": scan_id, "user_id": user_id})
            if result.deleted_count:
                logger.info("Scan deleted", scan_id=scan_id, user_id=user_id)
                return True
            logger.warning("Scan not found or user mismatch", scan_id=scan_id, user_id=user_id)
            return False
        except Exception as e:
            logger.error("Failed to delete scan", error=str(e))
            raise DatabaseError(f"Failed to delete scan: {str(e)}")

    @staticmethod
    def get_scan_count(user_id: str) -> int:
        try:
            return get_collection(COLLECTION).count_documents({"user_id": user_id})
        except Exception as e:
            logger.error("Failed to get scan count", error=str(e))
            return 0

    @staticmethod
    def update_scan_translations(scan_id: str, translations: Dict[str, Any]) -> None:
        try:
            coll = get_collection(COLLECTION)
            coll.update_one(
                {"scan_id": scan_id},
                {"$set": {"translations": translations, "updated_at": datetime.utcnow()}}
            )
            logger.info("Updated scan translations in database", scan_id=scan_id, languages=list(translations.keys()))
        except Exception as e:
            logger.error("Failed to update scan translations", scan_id=scan_id, error=str(e))


def _doc_to_scan_dict(d: dict) -> dict:
    return {
        "id": d.get("id", str(d.get("_id", ""))),
        "user_id": d.get("user_id"),
        "scan_id": d.get("scan_id"),
        "medication_name": d.get("medication_name"),
        "generic_name": d.get("generic_name"),
        "dosage": d.get("dosage"),
        "form": d.get("form"),
        "manufacturer": d.get("manufacturer"),
        "confidence": d.get("confidence"),
        "analysis_data": d.get("analysis_data"),
        "warnings": d.get("warnings", []),
        "contraindications": d.get("contraindications", []),
        "interactions": d.get("interactions", []),
        "side_effects": d.get("side_effects", []),
        "image_url": d.get("image_url"),
        "packaging_language": d.get("packaging_language"),
        "category": d.get("category"),
        "created_at": d.get("created_at"),
        "updated_at": d.get("updated_at"),
        "translations": d.get("translations", {}),
    }


scan_history_service = ScanHistoryService()
