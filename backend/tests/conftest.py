import os

os.environ["DATABASE_URL"] = "sqlite:////tmp/secure-commerce-tests.sqlite3"
os.environ["JWT_SECRET"] = "test-secret-that-is-long-enough-for-tests"
os.environ["AUTH_RATE_LIMIT"] = "100"

import pytest
from fastapi.testclient import TestClient

from app.db.session import Base, engine
from app.main import app
from app.middleware.rate_limit import auth_limiter


@pytest.fixture(autouse=True)
def fresh_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    auth_limiter._attempts.clear()
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def customer(client):
    payload = {"email": "alice@example.com", "password": "SecurePass!1", "first_name": "Alice", "last_name": "Jones"}
    response = client.post("/api/auth/register", json=payload)
    return {"user": response.json()["user"], "headers": {"Authorization": f"Bearer {response.json()['access_token']}"}}


@pytest.fixture
def admin(client):
    from app.auth.security import hash_password
    from app.db.session import SessionLocal
    from app.models import Cart, User, UserRole

    with SessionLocal() as db:
        user = User(email="admin@example.com", password_hash=hash_password("AdminPass!1"), first_name="Test", last_name="Admin", role=UserRole.admin)
        db.add(user); db.flush(); db.add(Cart(user_id=user.id)); db.commit()
    response = client.post("/api/auth/login", json={"email": "admin@example.com", "password": "AdminPass!1"})
    return {"user": response.json()["user"], "headers": {"Authorization": f"Bearer {response.json()['access_token']}"}}


@pytest.fixture
def product():
    from decimal import Decimal
    from app.db.session import SessionLocal
    from app.models import Product

    with SessionLocal() as db:
        item = Product(name="Test Keyboard", description="A very useful test keyboard", category="Electronics", price=Decimal("50.00"), stock_quantity=10, image_url=None)
        db.add(item); db.commit(); db.refresh(item)
        return item.id
