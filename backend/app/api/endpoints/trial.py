"""
Trial Endpoints
One-time trial per device
"""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Optional
import structlog
import jwt
import uuid
from datetime import datetime, timedelta

from app.services.auth_service import get_current_user_optional
from app.services.trial_service import has_used_trial, register_trial_device
from app.config import settings

logger = structlog.get_logger()

router = APIRouter()


class TrialCheckRequest(BaseModel):
    device_id: str


class TrialCheckResponse(BaseModel):
    can_use_trial: bool
    reason: Optional[str] = None


class TrialRegisterRequest(BaseModel):
    device_id: str


class TrialRegisterResponse(BaseModel):
    ok: bool


class TrialTokenRequest(BaseModel):
    device_id: str


class TrialTokenResponse(BaseModel):
    token: str
    uid: str


@router.post("/check", response_model=TrialCheckResponse)
async def check_trial(body: TrialCheckRequest) -> TrialCheckResponse:
    """
    Check if device can use trial (not yet used).
    """
    if not body.device_id or len(body.device_id) < 10:
        return TrialCheckResponse(can_use_trial=False, reason="device_id_invalid")
    used = has_used_trial(body.device_id)
    return TrialCheckResponse(can_use_trial=not used)


@router.post("/token", response_model=TrialTokenResponse)
async def get_trial_token(body: TrialTokenRequest) -> TrialTokenResponse:
    """
    Issue a signed JWT for trial mode (no Firebase anonymous auth required).
    Checks eligibility, registers device, and returns a backend-signed token.
    """
    if not body.device_id or len(body.device_id) < 10:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="device_id requis",
        )

    if has_used_trial(body.device_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="trial_already_used",
        )

    # Generate a stable anonymous UID for this device
    uid = f"trial_{uuid.uuid5(uuid.NAMESPACE_DNS, body.device_id).hex}"

    # Register the device
    register_trial_device(body.device_id, uid)

    # Issue a JWT signed with the backend secret
    payload = {
        "uid": uid,
        "is_anonymous": True,
        "is_trial": True,
        "device_id": body.device_id,
        "exp": datetime.utcnow() + timedelta(days=30),
        "iat": datetime.utcnow(),
    }
    token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)

    logger.info("Trial token issued", uid=uid, device_id=body.device_id[:16])
    return TrialTokenResponse(token=token, uid=uid)


@router.post("/register", response_model=TrialRegisterResponse)
async def register_trial(
    body: TrialRegisterRequest,
    user: Optional[dict] = Depends(get_current_user_optional),
) -> TrialRegisterResponse:
    """
    Register device as having used trial (called when user starts trial).
    """
    if not body.device_id or len(body.device_id) < 10:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="device_id requis",
        )
    user_id = user["uid"] if user else "anonymous"
    register_trial_device(body.device_id, user_id)
    return TrialRegisterResponse(ok=True)
