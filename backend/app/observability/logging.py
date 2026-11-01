import hashlib
import ipaddress
import json
import logging
import sys
from datetime import datetime, timezone

from app.core.config import get_settings


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
        }
        for key in (
            "event_type", "request_id", "method", "path", "status_code",
            "duration_ms", "user_id", "user_role", "source_ip", "user_agent", "email_hash",
            "simulation_id",
        ):
            value = getattr(record, key, None)
            if value is not None:
                payload[key] = value
        return json.dumps(payload, default=str)


def configure_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(get_settings().log_level.upper())


logger = logging.getLogger("secure_commerce")


def security_event(request, event_type: str, message: str, level: int = logging.INFO, **fields) -> None:
    context = {
        "event_type": event_type,
        "request_id": getattr(request.state, "request_id", None),
        "simulation_id": getattr(request.state, "simulation_id", None),
        "source_ip": source_ip(request),
        "method": request.method,
        "path": request.url.path,
        "user_agent": request.headers.get("user-agent", "")[:300],
        **fields,
    }
    logger.log(level, message, extra=context)


def source_ip(request) -> str:
    try:
        peer = ipaddress.ip_address(request.client.host)
        networks = [ipaddress.ip_network(value.strip()) for value in get_settings().trusted_proxy_cidrs.split(",") if value.strip()]
        forwarded_for = request.headers.get("x-forwarded-for", "")
        candidate = forwarded_for.rsplit(",", 1)[-1].strip() if forwarded_for and any(peer in network for network in networks) else str(peer)
        observed = ipaddress.ip_address(candidate)
        return str(observed) if observed.is_global else "unknown"
    except (AttributeError, ValueError):
        return "unknown"


def anonymize_email(email: str) -> str:
    return hashlib.sha256(email.strip().lower().encode()).hexdigest()[:16]
