"""
Configuration Management
Centralized settings with environment-based validation
"""

from pydantic_settings import BaseSettings
from typing import Optional, List
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings with validation"""
    
    # Environment
    ENVIRONMENT: str = "development"
    DEBUG: bool = True
    
    # API
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8888  # Changé pour correspondre au frontend
    API_VERSION: str = "v1"
    API_PREFIX: str = "/api/v1"
    API_PUBLIC_URL: Optional[str] = None  # URL publique du backend (ex: https://xxx.run.app)
    CORS_ORIGINS: str = "http://localhost:3001,http://localhost:3002"
    
    # MongoDB (remplace Cloud SQL + GCS)
    MONGODB_URI: str = "mongodb://localhost:27017"
    
    # Google Gemini AI
    GEMINI_API_KEY: str
    GEMINI_API_KEY_2: Optional[str] = None
    GEMINI_MODEL_VISION: str = "gemini-2.5-flash"  # Gemini 2.5 Flash for vision
    GEMINI_MODEL_CHAT: str = "gemini-2.5-flash"  # Gemini 2.5 Flash for chat
    GEMINI_MAX_TOKENS: int = 4096  # Reduced for faster responses
    GEMINI_TEMPERATURE: float = 0.7
    
    # Firebase
    FIREBASE_PROJECT_ID: str
    FIREBASE_CREDENTIALS_PATH: Optional[str] = None
    FIREBASE_CREDENTIALS_JSON: Optional[str] = None  # JSON string (pour Render sans fichier)
    
    # Firestore (chats / analytics - inchangé)
    FIRESTORE_COLLECTION_HISTORY: str = "scan_history"
    FIRESTORE_COLLECTION_CHATS: str = "ai_chats"
    FIRESTORE_COLLECTION_ANALYTICS: str = "app_analytics"
    FIRESTORE_COLLECTION_TRIAL_DEVICES: str = "trial_devices"

    # Admin (dashboard) - auth indépendante de l'app
    ADMIN_EMAIL: str = "seinimomo1@gmail.com"
    ADMIN_PASSWORD: str = ""  # Mot de passe dashboard (env ADMIN_PASSWORD)
    
    # Security
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_MINUTES: int = 1440
    
    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = 20
    RATE_LIMIT_PER_HOUR: int = 200
    
    # Redis
    REDIS_URL: Optional[str] = None
    
    # Monitoring
    SENTRY_DSN: Optional[str] = None
    
    # Medical
    MEDICAL_DISCLAIMER_REQUIRED: bool = True
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"
    
    @property
    def database_url(self) -> str:
        """Legacy: SQLite fallback (medication_service non migré). Principal = MongoDB."""
        return "sqlite:///./mediscan.db"

    @property
    def is_production(self) -> bool:
        """Check if running in production"""
        return self.ENVIRONMENT == "production"
    
    @property
    def cors_origins_list(self) -> List[str]:
        """Parse CORS origins"""
        if isinstance(self.CORS_ORIGINS, str):
            return [origin.strip() for origin in self.CORS_ORIGINS.split(",")]
        return self.CORS_ORIGINS


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance"""
    return Settings()


# Export for easy import
settings = get_settings()

