import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from sqlalchemy import text

from app.api import admin, auth, cart, orders, products
from app.core.config import get_settings
from app.db.session import SessionLocal
from app.middleware.http import RequestContextMiddleware
from app.observability.logging import configure_logging, logger, security_event

configure_logging()
settings = get_settings()
app = FastAPI(title=settings.app_name, version="1.0.0", docs_url="/api/docs", openapi_url="/api/openapi.json")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
)
app.add_middleware(RequestContextMiddleware)

app.include_router(auth.router, prefix="/api")
app.include_router(products.router, prefix="/api")
app.include_router(cart.router, prefix="/api")
app.include_router(orders.router, prefix="/api")
app.include_router(admin.router, prefix="/api")


@app.get("/health", tags=["operations"])
def health():
    return {"status": "healthy"}


@app.get("/ready", tags=["operations"])
def ready(request: Request):
    try:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
        return {"status": "ready", "database": "connected"}
    except Exception:
        logger.exception("Readiness database check failed", extra={"event_type": "DEPENDENCY_UNAVAILABLE", "request_id": request.state.request_id})
        return JSONResponse(status_code=503, content={"status": "not ready", "database": "unavailable", "request_id": request.state.request_id})


@app.get("/metrics", include_in_schema=False)
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.exception_handler(RequestValidationError)
async def validation_error(request: Request, exc: RequestValidationError):
    security_event(request, "VALIDATION_FAILURE", "Request validation failed", logging.WARNING)
    errors = []
    for error in exc.errors():
        safe = {key: value for key, value in error.items() if key not in {"input", "ctx"}}
        errors.append(safe)
    return JSONResponse(status_code=422, content={"error": "Validation failed", "details": errors, "request_id": request.state.request_id})


@app.exception_handler(Exception)
async def unhandled_error(request: Request, exc: Exception):
    logger.exception("Unhandled application error", extra={"event_type": "APPLICATION_ERROR", "request_id": request.state.request_id})
    return JSONResponse(status_code=500, content={"error": "Internal server error", "request_id": request.state.request_id})
