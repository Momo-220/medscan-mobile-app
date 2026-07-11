"""
MongoDB connection and collections.
Remplace PostgreSQL (Cloud SQL) pour Render.
"""

from pymongo import MongoClient
from pymongo.database import Database
from pymongo.collection import Collection
import structlog

from app.config import settings

logger = structlog.get_logger()

_client: MongoClient | None = None
_db: Database | None = None


def get_mongo_client() -> MongoClient:
    global _client
    if _client is None:
        _client = MongoClient(
            settings.MONGODB_URI,
            serverSelectionTimeoutMS=5000,
        )
        logger.info("MongoDB client created")
    return _client


def get_db() -> Database:
    global _db
    if _db is None:
        client = get_mongo_client()
        # Nom de la base depuis l'URI ou défaut (sécurisé avec parse_uri)
        db_name = "mediscan"
        try:
            from pymongo.uri_parser import parse_uri
            parsed_uri = parse_uri(settings.MONGODB_URI)
            if parsed_uri.get("database"):
                db_name = parsed_uri["database"]
        except Exception as e:
            logger.warning("Erreur lors du parsing de MONGODB_URI, utilisation de la base par défaut", error=str(e))
            # Fallback basique si le parseur échoue
            if "/" in settings.MONGODB_URI.rstrip("/"):
                path = settings.MONGODB_URI.split("/")[-1].split("?")[0]
                if path and ":" not in path and path != "mongodb.net":
                    db_name = path
        
        _db = client[db_name]
        logger.info("MongoDB database initialized", db=db_name)
    return _db


def get_collection(name: str) -> Collection:
    return get_db()[name]


def close_mongo():
    global _client
    if _client:
        _client.close()
        _client = None
        logger.info("MongoDB client closed")
