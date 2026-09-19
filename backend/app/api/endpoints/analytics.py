"""
Analytics Endpoints
Track events and get stats (admin)
"""

from fastapi import APIRouter, Depends, HTTPException, status, Request
from typing import Dict, Any, Optional
from pydantic import BaseModel
import structlog

from app.services.auth_service import get_current_user, get_current_user_optional
from app.services.admin_auth_service import verify_admin_token
from app.services.analytics_service import track_event, get_stats
from app.config import settings
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

logger = structlog.get_logger()

router = APIRouter()
security = HTTPBearer(auto_error=False)


def _get_client_ip(request: Request) -> str:
    """Extract real client IP from request.
    
    Reads the LAST entry in X-Forwarded-For, which is set by the trusted
    reverse proxy (Render). The first entries can be spoofed by the client.
    Falls back to the direct connection IP.
    """
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        ips = [ip.strip() for ip in forwarded.split(",")]
        return ips[-1] if ips else ""
    return request.client.host if request.client else ""


class TrackEventRequest(BaseModel):
    event_type: str
    device_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class TrackEventResponse(BaseModel):
    ok: bool


@router.post("/track", response_model=TrackEventResponse)
async def track_event_endpoint(
    body: TrackEventRequest,
    request: Request,
    user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
) -> TrackEventResponse:
    """
    Track an analytics event. Works with or without auth.
    """
    user_id = (user or {}).get("uid")
    ip = _get_client_ip(request)
    await track_event(
        event_type=body.event_type,
        user_id=user_id,
        device_id=body.device_id,
        metadata=body.metadata,
        ip=ip,
    )
    return TrackEventResponse(ok=True)


async def _get_admin_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> Dict[str, Any]:
    """
    Accepte soit le token dashboard (Bearer), soit Firebase JWT admin.
    """
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token requis",
        )
    token = credentials.credentials

    # 1. Token dashboard
    admin_payload = verify_admin_token(token)
    if admin_payload:
        return {"uid": "admin", "email": settings.ADMIN_EMAIL}

    # 2. Firebase JWT admin
    from app.services.firebase_service import firebase_service
    try:
        user = await firebase_service.verify_token(token)
        if user.get("email", "").lower() == settings.ADMIN_EMAIL.lower():
            return user
    except Exception:
        pass

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Accès réservé à l'administrateur",
    )


@router.get("/stats")
async def stats(
    user: Dict[str, Any] = Depends(_get_admin_user),
    days: int = 30,
) -> Dict[str, Any]:
    """
    Get analytics stats (admin only).
    Auth: token dashboard (POST /admin/login) OU Firebase admin.
    """
    if days < 1 or days > 365:
        days = 30
    return await get_stats(days=days)
