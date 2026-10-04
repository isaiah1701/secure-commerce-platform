import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.auth.security import create_access_token, hash_password, verify_password
from app.core.config import get_settings
from app.db.session import get_db
from app.middleware.rate_limit import rate_limit_login, rate_limit_register
from app.models import Cart, User
from app.observability.logging import anonymize_email, security_event
from app.observability.metrics import LOGIN_FAILURE, LOGIN_SUCCESS
from app.schemas.api import LoginRequest, TokenOut, UserCreate, UserOut

router = APIRouter(prefix="/auth", tags=["authentication"])


@router.post("/register", response_model=TokenOut, status_code=status.HTTP_201_CREATED, dependencies=[Depends(rate_limit_register)])
def register(data: UserCreate, request: Request, db: Session = Depends(get_db)):
    email = data.email.lower()
    if db.scalar(select(User).where(func.lower(User.email) == email)):
        security_event(request, "AUTH_REGISTER_FAILURE", "Registration rejected", logging.WARNING, email_hash=anonymize_email(email))
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Unable to register with those details")
    user = User(
        email=email,
        password_hash=hash_password(data.password),
        first_name=data.first_name.strip(),
        last_name=data.last_name.strip(),
    )
    db.add(user)
    db.flush()
    db.add(Cart(user_id=user.id))
    db.commit()
    db.refresh(user)
    security_event(request, "AUTH_REGISTER_SUCCESS", "Customer registered", user_id=user.id, user_role=user.role.value)
    return TokenOut(access_token=create_access_token(user.id, user.role.value), user=user)


@router.post("/login", response_model=TokenOut, dependencies=[Depends(rate_limit_login)])
def login(data: LoginRequest, request: Request, db: Session = Depends(get_db)):
    settings = get_settings()
    email = data.email.lower()
    user = db.scalar(select(User).where(func.lower(User.email) == email))
    now = datetime.now(timezone.utc)
    locked_until = user.locked_until if user else None
    if locked_until and locked_until.tzinfo is None:
        locked_until = locked_until.replace(tzinfo=timezone.utc)

    if user and locked_until and locked_until > now:
        LOGIN_FAILURE.inc()
        security_event(request, "AUTH_ACCOUNT_LOCKED", "Login rejected for locked account", logging.WARNING, email_hash=anonymize_email(email), user_id=user.id)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password.")

    if user and locked_until and locked_until <= now:
        user.failed_login_attempts = 0
        user.locked_until = None

    if not user or not user.is_active or not verify_password(data.password, user.password_hash):
        LOGIN_FAILURE.inc()
        if user and user.is_active:
            user.failed_login_attempts += 1
            if user.failed_login_attempts >= settings.login_max_attempts:
                user.locked_until = now + timedelta(minutes=settings.login_lock_minutes)
                security_event(request, "AUTH_ACCOUNT_LOCKED", "Account locked after repeated failures", logging.WARNING, email_hash=anonymize_email(email), user_id=user.id)
            db.commit()
        security_event(request, "AUTH_LOGIN_FAILURE", "Login attempt failed", logging.WARNING, email_hash=anonymize_email(email))
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password.")

    user.failed_login_attempts = 0
    user.locked_until = None
    user.last_login_at = now
    db.commit()
    db.refresh(user)
    LOGIN_SUCCESS.inc()
    security_event(request, "AUTH_LOGIN_SUCCESS", "Login succeeded", user_id=user.id, user_role=user.role.value)
    return TokenOut(access_token=create_access_token(user.id, user.role.value), user=user)


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(request: Request, user: User = Depends(get_current_user)):
    security_event(request, "AUTH_LOGOUT", "User signed out", user_id=user.id, user_role=user.role.value)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
