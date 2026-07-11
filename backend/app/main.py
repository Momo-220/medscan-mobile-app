"""
FastAPI Application Entry Point
Premium Medical Minimalism meets Production-Grade Architecture
"""

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from contextlib import asynccontextmanager
import asyncio
import structlog
from typing import Dict

from app.config import settings
from app.core.logging_config import setup_logging
from app.api.routes import router as api_router
from app.core.exceptions import MediScanException

# Rate limiting (SlowAPI - compatible async FastAPI)
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Setup structured logging
setup_logging()
logger = structlog.get_logger()




async def _background_init_heavy_services():
    """
    Chronologie de chargement : Gemini et Storage en arrière-plan.
    L'app répond à /health et aux requêtes auth dès que MongoDB + Firebase sont prêts.
    Scan/chat déclenchent initialize() si pas encore prêt (idempotent).
    """
    from app.services.gemini_service import gemini_service
    from app.services.storage_service import storage_service
    from app.services.medication_db_service import medication_db_service
    
    try:
        await gemini_service.initialize()
        logger.info("Background init: Gemini ready")
    except Exception as e:
        logger.warning("Background Gemini init failed (scan/chat will init on first use)", error=str(e))
    try:
        await storage_service.initialize()
        logger.info("Background init: Storage ready")
    except Exception as e:
        logger.warning("Background Storage init failed (scan will init on first use)", error=str(e))
    try:
        # Charger la base de données locale dans un thread séparé pour ne pas bloquer l'event loop
        logger.info("Background init: Loading local medication database...")
        await asyncio.to_thread(medication_db_service.load_data)
        logger.info("Background init: Local medication database loaded")
    except Exception as e:
        logger.error("Background local DB init failed", error=str(e))


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Chronologie de démarrage (optimisation cold start / 512 Mo):
    1. MongoDB (connexion) – priorité
    2. Firebase (auth requise pour credits/history/reminders)
    3. App prête → yield → /health et routes auth répondent tout de suite
    4. En arrière-plan: Gemini puis Storage (scan/chat peuvent les initialiser au premier besoin si pas encore prêts)
    """
    logger.info("AI MediScan Backend Starting...", environment=settings.ENVIRONMENT)

    from app.services.firebase_service import firebase_service
    from app.services.gemini_service import gemini_service
    from app.services.storage_service import storage_service
    from app.db.mongodb import get_db

    # 1. MongoDB (obligatoire pour DB)
    try:
        get_db()
    except Exception as e:
        logger.error("Failed to connect to MongoDB", error=str(e))

    # 2. Firebase (obligatoire pour auth – credits, history, reminders)
    await firebase_service.initialize()

    logger.info("AI MediScan Ready - Creating emotions, not just apps")

    # 3. Lancer Gemini + Storage en arrière-plan (n'attend pas pour accepter les requêtes)
    background_task = asyncio.create_task(_background_init_heavy_services())
    app.state._background_init_task = background_task

    yield

    # Shutdown
    logger.info("AI MediScan Shutting Down Gracefully")
    if hasattr(app.state, "_background_init_task"):
        background_task = app.state._background_init_task
        background_task.cancel()
        try:
            await background_task
        except asyncio.CancelledError:
            pass
    await firebase_service.cleanup()
    await gemini_service.cleanup()


# Initialize FastAPI Application
app = FastAPI(
    title="AI MediScan API",
    description="A calm, intelligent, and trustworthy pharmaceutical companion 💊✨",
    version="1.0.0",
    docs_url=f"{settings.API_PREFIX}/docs" if settings.DEBUG else None,
    redoc_url=f"{settings.API_PREFIX}/redoc" if settings.DEBUG else None,
    lifespan=lifespan,
)

# Rate limiting (SlowAPI)
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[f"{settings.RATE_LIMIT_PER_MINUTE}/minute", f"{settings.RATE_LIMIT_PER_HOUR}/hour"],
    enabled=True,
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


# ============================================================================
# MIDDLEWARE STACK
# UNIQUEMENT CORSMiddleware + GZip
# PAS de BaseHTTPMiddleware custom (casse les async dependencies de FastAPI)
# ============================================================================

app.add_middleware(GZipMiddleware, minimum_size=1000)

if settings.is_production:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["X-Request-ID"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["X-Request-ID"],
    )


# ============================================================================
# CORS HELPER
# ============================================================================

def _add_cors_headers(response: JSONResponse, request: Request) -> JSONResponse:
    """Ajoute les headers CORS a toute reponse"""
    origin = request.headers.get("origin", "")
    if settings.is_production:
        if origin in settings.cors_origins_list:
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Access-Control-Allow-Credentials"] = "true"
    else:
        response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Expose-Headers"] = "X-Request-ID"
    return response


# ============================================================================
# EXCEPTION HANDLERS (tous ajoutent les headers CORS)
# ============================================================================

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Handle Pydantic validation errors with detailed messages"""
    logger.error(
        "Validation Error",
        errors=exc.errors(),
        path=request.url.path,
        method=request.method,
    )
    response = JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": "Validation error",
            "detail": exc.errors(),
            "message": "Les données envoyées ne sont pas valides. Vérifiez que le message n'est pas vide et ne dépasse pas 2000 caractères.",
        },
    )
    return _add_cors_headers(response, request)

@app.exception_handler(MediScanException)
async def mediscan_exception_handler(request: Request, exc: MediScanException):
    """Handle custom application exceptions"""
    logger.error(
        "MediScan Exception",
        error=exc.message,
        status_code=exc.status_code,
        path=request.url.path,
    )
    response = JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.message,
            "code": exc.error_code,
            "details": exc.details,
        },
    )
    return _add_cors_headers(response, request)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handle unexpected exceptions"""
    logger.exception("Unexpected Error", exc_info=exc, path=request.url.path)
    response = JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "An unexpected error occurred. Our team has been notified.",
            "code": "INTERNAL_ERROR",
        },
    )
    return _add_cors_headers(response, request)


# ============================================================================
# STATIC FILES (Dev only - serve uploaded images)
# ============================================================================

if settings.ENVIRONMENT == "development":
    from fastapi.staticfiles import StaticFiles
    import os
    
    # Creer le dossier uploads s'il n'existe pas
    os.makedirs("./uploads", exist_ok=True)
    
    # Servir les fichiers uploades en dev
    app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
    logger.info(" DEV MODE: Serving /uploads directory for local images")


# ============================================================================
# HEALTH & ROOT ENDPOINTS
# ============================================================================

@app.get("/health", tags=["System"])
@limiter.exempt
async def health_check(request: Request) -> Dict[str, str]:
    """Health check endpoint (Render / load balancer)"""
    return {
        "status": "healthy",
        "service": "AI MediScan",
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT,
    }


@app.get("/", tags=["System"])
@limiter.exempt
async def root(request: Request) -> Dict[str, str]:
    """Root endpoint with welcome message"""
    return {
        "message": "✨ Welcome to AI MediScan - Your Pharmaceutical Companion",
        "docs": f"{settings.API_PREFIX}/docs" if settings.DEBUG else "Contact admin for API documentation",
        "status": "operational",
    }


# ============================================================================
# API ROUTES
# ============================================================================

app.include_router(api_router, prefix=settings.API_PREFIX)




if __name__ == "__main__":
    import uvicorn
    
    # reload=False en production (Render)
    uvicorn.run(
        "app.main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=False,
        log_level="info",
    )

