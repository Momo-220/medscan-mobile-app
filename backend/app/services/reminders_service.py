"""
Reminders persistence - MongoDB
"""

from typing import List, Optional, Dict, Any
from datetime import datetime, date
import uuid

from app.db.mongodb import get_collection

REMINDERS = "reminders"
REMINDER_TAKES = "reminder_takes"


def calculate_next_dose(time_str: str, frequency: str, days: Optional[List[int]] = None) -> datetime:
    from datetime import timedelta
    now = datetime.now()
    hour, minute = map(int, time_str.split(":"))
    next_dose = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    
    # 1. Base dose calculation by frequency
    if frequency == "twice":
        doses_today = [next_dose, next_dose + timedelta(hours=12)]
        candidates = [d for d in doses_today if d > now]
        if candidates:
            next_dose = candidates[0]
        else:
            next_dose = next_dose + timedelta(days=1)
    elif frequency == "three-times":
        doses_today = [next_dose, next_dose + timedelta(hours=8), next_dose + timedelta(hours=16)]
        candidates = [d for d in doses_today if d > now]
        if candidates:
            next_dose = candidates[0]
        else:
            next_dose = next_dose + timedelta(days=1)
    else:  # daily
        if next_dose <= now:
            next_dose += timedelta(days=1)
            
    # 2. Weekday constraint adjustment
    if days:
        loops = 0
        while next_dose.weekday() not in days and loops < 365:
            next_dose = next_dose.replace(hour=hour, minute=minute) + timedelta(days=1)
            loops += 1
            
    return next_dose


def create_reminder(user_id: str, data: Dict[str, Any]) -> Dict[str, Any]:
    reminder_id = str(uuid.uuid4())
    now = datetime.utcnow()
    next_dose = calculate_next_dose(data["time"], data["frequency"], data.get("days"))
    doc = {
        "id": reminder_id,
        "user_id": user_id,
        "medication_name": data["medication_name"],
        "dosage": data["dosage"],
        "time": data["time"],
        "frequency": data["frequency"],
        "days": data.get("days"),
        "notes": data.get("notes"),
        "active": True,
        "next_dose": next_dose,
        "created_at": now,
        "updated_at": now,
    }
    get_collection(REMINDERS).insert_one(doc)
    return doc


def get_reminders(user_id: str, active_only: bool = True, limit: int = 50) -> List[Dict[str, Any]]:
    q = {"user_id": user_id}
    if active_only:
        q["active"] = True
    cursor = get_collection(REMINDERS).find(q).sort("next_dose", 1).limit(limit)
    return list(cursor)


def count_medications_taken_today(user_id: str) -> int:
    today_start = datetime.combine(date.today(), datetime.min.time())
    today_end = datetime.combine(date.today(), datetime.max.time())
    return get_collection(REMINDER_TAKES).count_documents({
        "user_id": user_id,
        "taken_at": {"$gte": today_start, "$lte": today_end},
    })


def get_reminder_by_id(reminder_id: str, user_id: str) -> Optional[Dict[str, Any]]:
    return get_collection(REMINDERS).find_one({"id": reminder_id, "user_id": user_id})


def update_reminder(reminder_id: str, user_id: str, update_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    coll = get_collection(REMINDERS)
    doc = coll.find_one({"id": reminder_id, "user_id": user_id})
    if not doc:
        return None
    allowed = {"medication_name", "dosage", "time", "frequency", "days", "notes", "active", "next_dose"}
    set_data = {k: v for k, v in update_data.items() if k in allowed}
    if "time" in set_data or "frequency" in set_data:
        set_data["next_dose"] = calculate_next_dose(
            set_data.get("time", doc["time"]),
            set_data.get("frequency", doc["frequency"]),
            set_data.get("days", doc.get("days")),
        )
    set_data["updated_at"] = datetime.utcnow()
    coll.update_one({"id": reminder_id, "user_id": user_id}, {"$set": set_data})
    return get_collection(REMINDERS).find_one({"id": reminder_id, "user_id": user_id})


def delete_reminder(reminder_id: str, user_id: str) -> bool:
    result = get_collection(REMINDERS).delete_one({"id": reminder_id, "user_id": user_id})
    return result.deleted_count > 0


def mark_taken(reminder_id: str, user_id: str, taken_at: Optional[datetime] = None) -> Optional[datetime]:
    from datetime import timedelta
    coll = get_collection(REMINDERS)
    doc = coll.find_one({"id": reminder_id, "user_id": user_id})
    if not doc:
        return None
    taken_at = taken_at or datetime.utcnow()
    # next_dose
    base_next = doc["next_dose"]
    if doc["frequency"] == "daily":
        next_dose = base_next + timedelta(days=1)
    elif doc["frequency"] == "twice":
        next_dose = base_next + timedelta(hours=12)
    elif doc["frequency"] == "three-times":
        next_dose = base_next + timedelta(hours=8)
    else:
        next_dose = base_next + timedelta(days=1)
        
    days = doc.get("days")
    if days:
        hour, minute = map(int, doc["time"].split(":"))
        loops = 0
        while next_dose.weekday() not in days and loops < 365:
            next_dose = next_dose.replace(hour=hour, minute=minute) + timedelta(days=1)
            loops += 1

    coll.update_one(
        {"id": reminder_id, "user_id": user_id},
        {"$set": {"next_dose": next_dose, "updated_at": datetime.utcnow()}},
    )
    get_collection(REMINDER_TAKES).insert_one({
        "id": str(uuid.uuid4()),
        "reminder_id": reminder_id,
        "user_id": user_id,
        "taken_at": taken_at,
    })
    return next_dose


def _to_response(d: dict) -> dict:
    return {
        "id": d["id"],
        "medication_name": d["medication_name"],
        "dosage": d["dosage"],
        "time": d["time"],
        "frequency": d["frequency"],
        "days": d.get("days"),
        "notes": d.get("notes"),
        "active": d.get("active", True),
        "next_dose": d["next_dose"],
        "created_at": d["created_at"],
        "updated_at": d["updated_at"],
    }
