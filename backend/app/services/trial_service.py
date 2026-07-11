"""
Trial Service
One-time trial per device (Firestore)
"""

from typing import Optional
from datetime import datetime
import structlog

from app.db.mongodb import get_collection

logger = structlog.get_logger()
COLLECTION = "trial_devices"


def has_used_trial(device_id: str) -> bool:
    """Check if device has already used trial."""
    if not device_id:
        return False
    try:
        coll = get_collection(COLLECTION)
        doc = coll.find_one({"device_id": device_id})
        return doc is not None
    except Exception as e:
        logger.error("Trial check failed", device_id=device_id[:16], error=str(e))
        return False


def register_trial_device(device_id: str, user_id: str) -> None:
    """Register device as having used trial."""
    if not device_id:
        return
    try:
        coll = get_collection(COLLECTION)
        coll.update_one(
            {"device_id": device_id},
            {
                "$set": {
                    "device_id": device_id,
                    "user_id": user_id,
                    "used_at": datetime.utcnow(),
                }
            },
            upsert=True
        )
        logger.info("Trial device registered in MongoDB", device_id=device_id[:16])
    except Exception as e:
        logger.error("Trial register failed in MongoDB", error=str(e))

