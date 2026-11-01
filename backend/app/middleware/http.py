import logging
import re
import time
import uuid

from starlette.middleware.base import BaseHTTPMiddleware

from app.observability.logging import logger, security_event, source_ip
from app.observability.metrics import REQUEST_DURATION, REQUESTS

REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9._-]{1,100}$")
SUSPICIOUS = ("<script", "' or 1=1", "../", "%2e%2e", "%252e")


class RequestContextMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        supplied = request.headers.get("x-request-id", "")
        request.state.request_id = supplied if REQUEST_ID_RE.fullmatch(supplied) else str(uuid.uuid4())
        simulation_id = request.headers.get("x-soc-scenario-id", "")
        request.state.simulation_id = simulation_id if REQUEST_ID_RE.fullmatch(simulation_id) else None
        request.state.user_id = None
        request.state.user_role = None
        started = time.perf_counter()

        target = f"{request.url.path}?{request.url.query}".lower()
        content_length = request.headers.get("content-length", "")
        if (
            request.method in {"POST", "PUT", "PATCH"}
            and request.headers.get("content-type", "").startswith("application/json")
            and content_length.isdigit()
            and int(content_length) <= 16_384
        ):
            target += (await request.body()).decode("utf-8", errors="ignore").lower()
        if any(pattern in target for pattern in SUSPICIOUS):
            security_event(request, "SUSPICIOUS_REQUEST", "Suspicious request pattern detected", logging.WARNING)

        response = await call_next(request)
        duration_ms = round((time.perf_counter() - started) * 1000, 2)
        route = request.scope.get("route")
        metric_path = getattr(route, "path", request.url.path)
        REQUESTS.labels(request.method, metric_path, str(response.status_code)).inc()
        REQUEST_DURATION.labels(request.method, metric_path).observe(duration_ms / 1000)
        logger.info(
            "Request completed",
            extra={
                "event_type": "HTTP_REQUEST",
                "request_id": request.state.request_id,
                "simulation_id": request.state.simulation_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": duration_ms,
                "user_id": request.state.user_id,
                "user_role": request.state.user_role,
                "source_ip": source_ip(request),
                "user_agent": request.headers.get("user-agent", "")[:300],
            },
        )
        response.headers["X-Request-ID"] = request.state.request_id
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Content-Security-Policy"] = "default-src 'self'; img-src 'self' https: data:; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self' http://localhost:8000"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        return response
