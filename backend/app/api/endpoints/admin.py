"""
Admin Dashboard - Login indépendant de l'app
"""

from fastapi import APIRouter, HTTPException, status, Request
from pydantic import BaseModel
from typing import Optional
import hmac

from app.config import settings
from app.services.admin_auth_service import create_admin_token
from app.core.limiter import limiter

router = APIRouter()


class AdminLoginRequest(BaseModel):
    email: str
    password: str


class AdminLoginResponse(BaseModel):
    token: str


@router.post("/login", response_model=AdminLoginResponse)
@limiter.limit("5/minute")
async def admin_login(request: Request, body: AdminLoginRequest) -> AdminLoginResponse:
    """
    Connexion dashboard admin - indépendant de Firebase/app.
    Email et mot de passe configurés dans .env (ADMIN_EMAIL, ADMIN_PASSWORD).
    Limité à 5 tentatives/minute pour contrer le brute-force.
    """
    if not settings.ADMIN_PASSWORD:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Dashboard admin non configuré (ADMIN_PASSWORD manquant)",
        )

    # Constant-time comparison to prevent timing attacks
    email_match = hmac.compare_digest(
        body.email.strip().lower(),
        settings.ADMIN_EMAIL.lower()
    )
    password_match = hmac.compare_digest(
        body.password,
        settings.ADMIN_PASSWORD
    )

    if not email_match or not password_match:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Identifiants invalides")

    token = create_admin_token()
    return AdminLoginResponse(token=token)
