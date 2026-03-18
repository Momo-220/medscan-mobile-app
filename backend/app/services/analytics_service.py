"""
Analytics Service
Store and query app analytics in Firestore
"""

from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime, timedelta
import structlog
import httpx

from app.config import settings
from app.services.firebase_service import firebase_service

logger = structlog.get_logger()

# Mapping country name -> ISO 2-letter (pour drapeaux). ip-api.com retourne le nom.
COUNTRY_TO_CODE: Dict[str, str] = {
    "France": "FR", "United States": "US", "United Kingdom": "GB", "Germany": "DE",
    "Spain": "ES", "Italy": "IT", "Canada": "CA", "Belgium": "BE", "Switzerland": "CH",
    "Senegal": "SN", "Mali": "ML", "Ivory Coast": "CI", "Cameroon": "CM", "Morocco": "MA",
    "Algeria": "DZ", "Tunisia": "TN", "Nigeria": "NG", "Ghana": "GH", "Togo": "TG",
    "Benin": "BJ", "Burkina Faso": "BF", "Niger": "NE", "Guinea": "GN", "Mauritania": "MR",
    "Netherlands": "NL", "Portugal": "PT", "Brazil": "BR", "India": "IN", "China": "CN",
    "Japan": "JP", "South Korea": "KR", "Australia": "AU", "Russia": "RU", "Turkey": "TR",
    "Egypt": "EG", "South Africa": "ZA", "Kenya": "KE", "Côte d'Ivoire": "CI",
    "Local": "", "Unknown": "",
}


async def get_country_from_ip(ip: str) -> Tuple[str, str]:
    """Resolve IP to (country_name, country_code) via ip-api.com."""
    if not ip or ip in ("127.0.0.1", "::1", "localhost"):
        return ("Local", "")
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(
                f"http://ip-api.com/json/{ip}?fields=country,countryCode,status"
            )
            data = r.json()
            if data.get("status") == "success":
                name = data.get("country", "Unknown")
                code = data.get("countryCode", "") or COUNTRY_TO_CODE.get(name, "")
                return (name, code)
    except Exception as e:
        logger.warning("IP geolocation failed", ip=ip, error=str(e))
    return ("Unknown", "")


def _country_to_code(name: str) -> str:
    """Convertit un nom de pays en code ISO pour drapeau."""
    return COUNTRY_TO_CODE.get(name, "")


async def track_event(
    event_type: str,
    user_id: Optional[str],
    device_id: Optional[str],
    metadata: Optional[Dict[str, Any]] = None,
    ip: Optional[str] = None,
) -> None:
    """Store analytics event in Firestore."""
    if not firebase_service.db:
        return
    try:
        country_name, country_code = await get_country_from_ip(ip or "") if ip else ("Unknown", "")
        if not country_code and country_name:
            country_code = _country_to_code(country_name)
        doc = {
            "event_type": event_type,
            "user_id": user_id or "anonymous",
            "device_id": device_id,
            "country": country_name,
            "country_code": country_code,
            "metadata": metadata or {},
            "timestamp": datetime.utcnow().isoformat(),
        }
        firebase_service.db.collection(settings.FIRESTORE_COLLECTION_ANALYTICS).add(doc)
    except Exception as e:
        logger.error("Analytics track failed", error=str(e))


async def _get_trial_devices_count() -> int:
    """Nombre d'appareils ayant utilisé l'essai."""
    if not firebase_service.db:
        return 0
    try:
        ref = firebase_service.db.collection(settings.FIRESTORE_COLLECTION_TRIAL_DEVICES)
        return sum(1 for _ in ref.stream())
    except Exception:
        return 0


async def get_stats(days: int = 30) -> Dict[str, Any]:
    """Aggregate analytics stats for dashboard."""
    if not firebase_service.db:
        return _empty_stats()
    try:
        now = datetime.utcnow()
        since = now - timedelta(days=days)
        active_since = now - timedelta(minutes=5)
        ref = firebase_service.db.collection(settings.FIRESTORE_COLLECTION_ANALYTICS)
        docs = ref.where("timestamp", ">=", since.isoformat()).stream()

        events: List[Dict[str, Any]] = []
        users = set()
        active_users_5min = set()
        events_last_5min = 0
        trial_devices = set()
        countries: Dict[str, int] = {}
        countries_trial: Dict[str, int] = {}
        by_type: Dict[str, int] = {}
        by_day: Dict[str, int] = {}
        user_countries: Dict[str, str] = {}  # uid -> pays (dernier événement)

        for doc in docs:
            d = doc.to_dict()
            events.append(d)
            uid = d.get("user_id", "anonymous")
            device_id = d.get("device_id") or ""
            country = d.get("country", "Unknown")
            etype = d.get("event_type", "unknown")

            if uid and uid != "anonymous":
                users.add(uid)
                user_countries[uid] = country  # dernier vu remplace
            if etype == "trial_start" and device_id:
                trial_devices.add(device_id)
                countries_trial[country] = countries_trial.get(country, 0) + 1

            countries[country] = countries.get(country, 0) + 1
            by_type[etype] = by_type.get(etype, 0) + 1
            ts_full = d.get("timestamp", "")
            ts_day = ts_full[:10]
            if ts_day:
                by_day[ts_day] = by_day.get(ts_day, 0) + 1

            # Temps réel: activité des 5 dernières minutes
            if ts_full:
                try:
                    event_dt = datetime.fromisoformat(ts_full)
                except Exception:
                    event_dt = None
                if event_dt and event_dt >= active_since:
                    events_last_5min += 1
                    if uid and uid != "anonymous":
                        active_users_5min.add(uid)

        trial_count = await _get_trial_devices_count()
        firebase_users = await firebase_service.get_auth_user_stats()

        # Enrichir chaque utilisateur Firebase avec son pays (depuis les événements analytics)
        for u in firebase_users.get("users", []):
            uid = u.get("uid", "")
            country = user_countries.get(uid, "Unknown")
            u["country"] = country
            u["country_code"] = _country_to_code(country)

        # countries avec code pour drapeau
        countries_list = [
            {"name": k, "code": _country_to_code(k), "count": v}
            for k, v in sorted(countries.items(), key=lambda x: -x[1])
        ]

        countries_trial_list = [
            {"name": k, "code": _country_to_code(k), "count": v}
            for k, v in sorted(countries_trial.items(), key=lambda x: -x[1])
        ]

        return {
            "total_events": len(events),
            "unique_users": len(users),
            "unique_trial_users": len(trial_devices),
            "trial_devices_count": trial_count,
            "events_last_5min": events_last_5min,
            "active_users_5min": len(active_users_5min),
            "firebase_users": firebase_users,
            "countries": dict(sorted(countries.items(), key=lambda x: -x[1])),
            "countries_detail": countries_list,
            "countries_trial": dict(sorted(countries_trial.items(), key=lambda x: -x[1])),
            "countries_trial_detail": countries_trial_list,
            "by_event_type": by_type,
            "by_day": dict(sorted(by_day.items())),
            "period_days": days,
        }
    except Exception as e:
        logger.error("Analytics stats failed", error=str(e))
        return _empty_stats()


def _empty_stats() -> Dict[str, Any]:
    return {
        "total_events": 0,
        "unique_users": 0,
        "unique_trial_users": 0,
        "trial_devices_count": 0,
        "events_last_5min": 0,
        "active_users_5min": 0,
        "firebase_users": {"total": 0, "anonymous": 0, "registered": 0, "by_provider": {}, "users": []},
        "countries": {},
        "countries_detail": [],
        "countries_trial": {},
        "countries_trial_detail": [],
        "by_event_type": {},
        "by_day": {},
        "period_days": 0,
    }
