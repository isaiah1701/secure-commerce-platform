import logging
import threading
import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status

from app.core.config import get_settings
from app.observability.logging import security_event


class InMemoryRateLimiter:
    def __init__(self):
        self._attempts: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def check(self, request: Request, scope: str) -> None:
        settings = get_settings()
        now = time.monotonic()
        ip = request.client.host if request.client else "unknown"
        key = f"{scope}:{ip}"
        with self._lock:
            attempts = self._attempts[key]
            while attempts and attempts[0] <= now - settings.auth_rate_window_seconds:
                attempts.popleft()
            if len(attempts) >= settings.auth_rate_limit:
                security_event(request, "RATE_LIMIT_EXCEEDED", "Authentication rate limit exceeded", logging.WARNING)
                raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Too many requests. Try again later.")
            attempts.append(now)


auth_limiter = InMemoryRateLimiter()


def rate_limit_login(request: Request) -> None:
    auth_limiter.check(request, "login")


def rate_limit_register(request: Request) -> None:
    auth_limiter.check(request, "register")
