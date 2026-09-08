"""
Firebase Service
Authentication and Firestore operations
"""

import os
import json
import asyncio
import firebase_admin
from firebase_admin import credentials, auth, firestore
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone
import structlog

from app.config import settings
from app.core.exceptions import AuthenticationError, DatabaseError

logger = structlog.get_logger()


class FirebaseService:
    """Manage Firebase Authentication and Firestore"""

    def __init__(self) -> None:
        self.app: Optional[firebase_admin.App] = None
        # Use Any for db to avoid Pylance stub complaints with google-cloud-firestore
        self.db: Any = None
        self._initialized: bool = False

    async def initialize(self) -> None:
        """Initialize Firebase Admin SDK"""
        if self._initialized:
            return

        try:
            cred: Optional[credentials.Base] = None

            # 1) Variable d'environnement JSON (idéal pour Render)
            if settings.FIREBASE_CREDENTIALS_JSON:
                try:
                    cred_dict = json.loads(settings.FIREBASE_CREDENTIALS_JSON)
                    cred = credentials.Certificate(cred_dict)
                    logger.info("Using Firebase credentials from FIREBASE_CREDENTIALS_JSON")
                except Exception as e:
                    logger.error("Invalid FIREBASE_CREDENTIALS_JSON", error=str(e))
                    self._initialized = True
                    return

            # 2) Fichier credentials
            if (
                cred is None
                and settings.FIREBASE_CREDENTIALS_PATH
                and os.path.exists(settings.FIREBASE_CREDENTIALS_PATH)
            ):
                cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
                logger.info("Using Firebase credentials file")

            # 3) Application Default Credentials (optionnel)
            if cred is None:
                try:
                    cred = credentials.ApplicationDefault()
                    logger.info("Using Application Default Credentials for Firebase")
                except Exception as adc_error:
                    logger.warning(
                        "Firebase credentials not found - Running without Firebase",
                        error=str(adc_error),
                    )
                    self._initialized = True
                    return

            self.app = firebase_admin.initialize_app(
                cred,
                {"projectId": settings.FIREBASE_PROJECT_ID},
            )

            # Initialize Firestore client
            self.db = firestore.client()

            self._initialized = True
            logger.info("Firebase initialized successfully")

        except Exception as e:
            logger.error("Firebase initialization failed", error=str(e))
            logger.warning("Continuing without Firebase - Auth may not work")
            self._initialized = True

    async def verify_token(self, token: str) -> Dict[str, Any]:
        """
        Verify Firebase ID token.
        Returns user data dict if valid.
        """
        if not self._initialized or not self.app:
            logger.error("Firebase not initialized - cannot verify token")
            raise AuthenticationError("Firebase authentication service not available")

        try:
            decoded_token: Dict[str, Any] = auth.verify_id_token(token)  # type: ignore[assignment]
            firebase_claims: Dict[str, Any] = decoded_token.get("firebase", {}) or {}
            sign_in_provider: str = firebase_claims.get("sign_in_provider", "")
            is_anonymous: bool = sign_in_provider == "anonymous"
            return {
                "uid": decoded_token["uid"],
                "email": decoded_token.get("email"),
                "email_verified": decoded_token.get("email_verified", False),
                "is_anonymous": is_anonymous,
            }
        except auth.ExpiredIdTokenError:
            logger.warning("Expired Firebase token provided")
            raise AuthenticationError("Authentication token has expired")
        except auth.InvalidIdTokenError:
            logger.warning("Invalid Firebase token provided")
            raise AuthenticationError("Invalid authentication token")
        except Exception as e:
            logger.error(
                "Token verification failed",
                error=str(e),
                error_type=type(e).__name__,
            )
            raise AuthenticationError("Authentication failed")

    async def get_user(self, uid: str) -> Optional[Dict[str, Any]]:
        """Get user data from Firebase Auth"""
        try:
            user = auth.get_user(uid)
            return {
                "uid": user.uid,
                "email": user.email,
                "email_verified": user.email_verified,
                "display_name": user.display_name,
                "photo_url": user.photo_url,
                "created_at": user.user_metadata.creation_timestamp,
            }
        except auth.UserNotFoundError:
            return None
        except Exception as e:
            logger.error("Failed to get user", uid=uid, error=str(e))
            return None

    async def get_auth_user_stats(self) -> Dict[str, Any]:
        """
        Compte les utilisateurs Firebase Authentication (ceux de la console Firebase).
        Retourne: total, anonymes, inscrits (email/google), liste par fournisseur.
        """
        if not self.app:
            return {"total": 0, "anonymous": 0, "registered": 0, "by_provider": {}, "users": []}

        try:
            page = auth.list_users(max_results=1000)

            def _fetch() -> tuple[int, int, int, Dict[str, int], List[Dict[str, Any]]]:
                total = anonymous = 0
                by_provider: Dict[str, int] = {}
                users: List[Dict[str, Any]] = []
                for user in page.iterate_all():
                    total += 1
                    # Anonyme = pas d'email ni téléphone
                    is_anon = not user.email and not user.phone_number
                    if is_anon:
                        anonymous += 1
                        prov = "anonymous"
                    else:
                        prov = (
                            user.provider_data[0].provider_id
                            if user.provider_data
                            else "password"
                        )
                        by_provider[prov] = by_provider.get(prov, 0) + 1
                    users.append(
                        {
                            "uid": user.uid,
                            "email": user.email or "(anonyme)",
                            "provider": prov,
                            "created": getattr(user.user_metadata, "creation_timestamp", None),
                        }
                    )
                return total, anonymous, total - anonymous, by_provider, users[:50]

            total, anonymous, registered, by_provider, users = await asyncio.to_thread(_fetch)
            return {
                "total": total,
                "anonymous": anonymous,
                "registered": registered,
                "by_provider": by_provider,
                "users": users,
            }
        except Exception as e:
            logger.error("Firebase Auth list users failed", error=str(e))
            return {"total": 0, "anonymous": 0, "registered": 0, "by_provider": {}, "users": []}

    # ========================================================================
    # FIRESTORE OPERATIONS - AI Chat History
    # Note: Scan history has been moved to PostgreSQL (see scan_history_service.py)
    # ========================================================================

    async def save_chat_message(
        self,
        user_id: str,
        message: Dict[str, Any],
    ) -> str:
        """Save AI chat message to Firestore"""
        try:
            doc_ref = self.db.collection(settings.FIRESTORE_COLLECTION_CHATS).document()

            data: Dict[str, Any] = {
                "user_id": user_id,
                "message_id": doc_ref.id,
                "timestamp": firestore.SERVER_TIMESTAMP,  # type: ignore[attr-defined]
                "created_at": datetime.now(timezone.utc).isoformat(),
                **message,
            }

            doc_ref.set(data)
            return str(doc_ref.id)

        except Exception as e:
            logger.error("Failed to save chat message", error=str(e))
            raise DatabaseError("Failed to save chat message")

    async def get_chat_history(
        self,
        user_id: str,
        limit: int = 100,
    ) -> List[Dict[str, Any]]:
        """Get user's chat history from Firestore"""
        try:
            # Note: No order_by to avoid requiring a composite Firestore index.
            # Sorting is done client-side in Flutter (ascending by timestamp).
            query = (
                self.db.collection(settings.FIRESTORE_COLLECTION_CHATS)
                .where("user_id", "==", user_id)
                .limit(limit)
            )

            docs = query.stream()

            messages: List[Dict[str, Any]] = []
            for doc in docs:
                data: Dict[str, Any] = doc.to_dict()
                data["id"] = doc.id
                messages.append(data)

            # Sort by created_at string (ISO format) ascending — no composite index needed
            messages.sort(key=lambda m: m.get("created_at", ""), reverse=False)

            return messages

        except Exception as e:
            logger.error("Failed to get chat history", error=str(e))
            raise DatabaseError("Failed to retrieve chat history")

    async def cleanup(self) -> None:
        """Cleanup Firebase resources"""
        if self.app:
            firebase_admin.delete_app(self.app)
            self._initialized = False
            logger.info("Firebase cleanup completed")


# Singleton instance
firebase_service = FirebaseService()
