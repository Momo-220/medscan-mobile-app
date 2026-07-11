"""
Authentication Service
JWT validation and user access control
"""

from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Dict, Any, Optional
import structlog
import jwt as pyjwt

from app.services.firebase_service import firebase_service
from app.core.exceptions import AuthenticationError, AuthorizationError
from app.config import settings

logger = structlog.get_logger()

# HTTP Bearer token scheme
security = HTTPBearer()
security_optional = HTTPBearer(auto_error=False)


def _try_local_jwt(token: str) -> Optional[Dict[str, Any]]:
    """Try to decode a backend-signed trial JWT. Returns None if not valid."""
    try:
        payload = pyjwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        # Only accept tokens explicitly marked as trial
        if payload.get("is_trial"):
            return payload
    except Exception:
        pass
    return None


# Fonctions de dependance simples (pas de static methods - meilleure compat FastAPI)

async def verify_token(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> Dict[str, Any]:
    """
    Verify Firebase JWT token or backend-signed trial JWT token.
    Use as FastAPI dependency for protected routes
    """
    token = credentials.credentials

    # First, try a local trial JWT (no Firebase needed)
    local_payload = _try_local_jwt(token)
    if local_payload:
        logger.info("Trial user authenticated (local JWT)", uid=local_payload.get("uid"))
        return local_payload

    try:
        user_data = await firebase_service.verify_token(token)
        
        logger.info("User authenticated", user_id=user_data["uid"])
        return user_data
        
    except AuthenticationError:
        raise
    except Exception as e:
        logger.error("Authentication failed", error=str(e))
        raise AuthenticationError("Invalid authentication")


async def get_current_user(
    user_data: Dict[str, Any] = Depends(verify_token),
) -> Dict[str, Any]:
    """
    Get current authenticated user
    Use as dependency to access user info in routes
    """
    return user_data


async def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_optional),
) -> Optional[Dict[str, Any]]:
    """
    Get current user if token present, None otherwise.
    Use for routes that work with or without auth.
    """
    if not credentials or not credentials.credentials:
        return None
    # Try local trial JWT first
    local_payload = _try_local_jwt(credentials.credentials)
    if local_payload:
        return local_payload
    try:
        return await firebase_service.verify_token(credentials.credentials)
    except Exception:
        return None


async def require_full_account(
    user_data: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    """
    Exige un compte inscrit (pas anonyme). Utiliser pour historique, rappels, etc.
    Les utilisateurs en mode essai reçoivent 403.
    """
    if user_data.get("is_anonymous"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inscrivez-vous pour utiliser cette fonctionnalité",
        )
    return user_data


async def require_verified_email(
    user_data: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    """
    Require user to have verified email
    Use for sensitive operations
    """
    if not user_data.get("email_verified"):
        raise AuthorizationError("Email verification required")
    
    return user_data


