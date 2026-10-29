import logging

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.auth.security import decode_access_token
from app.db.session import get_db
from app.models import User, UserRole
from app.observability.logging import security_event

bearer = HTTPBearer(auto_error=False)


def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    if not credentials or credentials.scheme.lower() != "bearer":
        security_event(request, "AUTH_UNAUTHORIZED", "Authentication required", logging.WARNING)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
    try:
        payload = decode_access_token(credentials.credentials)
        user_id = int(payload["sub"])
    except (jwt.PyJWTError, KeyError, TypeError, ValueError):
        security_event(request, "AUTH_UNAUTHORIZED", "Invalid authentication token", logging.WARNING)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token") from None
    user = db.get(User, user_id)
    if not user or not user.is_active:
        security_event(request, "AUTH_UNAUTHORIZED", "Inactive or missing token subject", logging.WARNING)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")
    request.state.user_id = user.id
    request.state.user_role = user.role.value
    return user


def require_admin(request: Request, user: User = Depends(get_current_user)) -> User:
    if user.role != UserRole.admin:
        security_event(request, "AUTH_FORBIDDEN", "Admin access denied", logging.WARNING, user_id=user.id, user_role=user.role.value)
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user
