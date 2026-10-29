from app.db.session import SessionLocal
from app.models import Product, User


def register(client, email="bob@example.com"):
    return client.post("/api/auth/register", json={"email": email, "password": "SecurePass!1", "first_name": "Bob", "last_name": "Smith"})


def test_health_and_readiness(client):
    assert client.get("/health").json() == {"status": "healthy"}
    assert client.get("/ready").status_code == 200
    assert client.get("/metrics").status_code == 200


def test_registration_never_returns_password(client):
    response = register(client)
    assert response.status_code == 201
    assert "password" not in response.text.lower()
    assert response.headers["x-request-id"]


def test_duplicate_and_malformed_registration_rejected(client):
    assert register(client).status_code == 201
    assert register(client).status_code == 409
    weak = client.post("/api/auth/register", json={"email": "not-an-email", "password": "weak", "first_name": "A", "last_name": "B"})
    assert weak.status_code == 422
    assert weak.json()["error"] == "Validation failed"


def test_successful_and_failed_login(client):
    register(client)
    good = client.post("/api/auth/login", json={"email": "bob@example.com", "password": "SecurePass!1"})
    bad = client.post("/api/auth/login", json={"email": "bob@example.com", "password": "WrongPass!1"})
    assert good.status_code == 200
    assert bad.status_code == 401
    assert bad.json()["detail"] == "Invalid email or password."


def test_account_locks_after_five_failures(client):
    register(client)
    for _ in range(5):
        assert client.post("/api/auth/login", json={"email": "bob@example.com", "password": "WrongPass!1"}).status_code == 401
    locked = client.post("/api/auth/login", json={"email": "bob@example.com", "password": "SecurePass!1"})
    assert locked.status_code == 401
    with SessionLocal() as db:
        user = db.query(User).filter(User.email == "bob@example.com").one()
        assert user.failed_login_attempts == 5
        assert user.locked_until is not None


def test_unauthenticated_and_invalid_jwt_rejected(client):
    assert client.get("/api/cart").status_code == 401
    assert client.get("/api/cart", headers={"Authorization": "Bearer invalid.token.value"}).status_code == 401


def test_products_list_and_detail(client, product):
    response = client.get("/api/products?search=keyboard&category=Electronics")
    assert response.status_code == 200 and len(response.json()) == 1
    assert client.get(f"/api/products/{product}").json()["name"] == "Test Keyboard"
    assert client.get("/api/products/99999").status_code == 404


def test_customer_cannot_access_admin(client, customer):
    response = client.get("/api/admin/users", headers=customer["headers"])
    assert response.status_code == 403


def test_admin_can_create_and_update_product(client, admin):
    data = {"name": "New Lamp", "description": "A sturdy and bright desk lamp", "category": "Home", "price": 35.5, "stock_quantity": 8, "image_url": None, "active": True}
    created = client.post("/api/admin/products", headers=admin["headers"], json=data)
    assert created.status_code == 201
    data["stock_quantity"] = 22
    updated = client.put(f"/api/admin/products/{created.json()['id']}", headers=admin["headers"], json=data)
    assert updated.status_code == 200 and updated.json()["stock_quantity"] == 22


def test_cart_add_update_remove_and_quantity_validation(client, customer, product):
    added = client.post("/api/cart/items", headers=customer["headers"], json={"product_id": product, "quantity": 2})
    assert added.status_code == 201 and added.json()["total"] == "100.00"
    item_id = added.json()["items"][0]["id"]
    assert client.put(f"/api/cart/items/{item_id}", headers=customer["headers"], json={"quantity": 0}).status_code == 422
    updated = client.put(f"/api/cart/items/{item_id}", headers=customer["headers"], json={"quantity": 3})
    assert updated.json()["total"] == "150.00"
    removed = client.delete(f"/api/cart/items/{item_id}", headers=customer["headers"])
    assert removed.status_code == 200 and removed.json()["items"] == []


def test_checkout_reduces_stock_and_clears_cart(client, customer, product):
    client.post("/api/cart/items", headers=customer["headers"], json={"product_id": product, "quantity": 3})
    checked_out = client.post("/api/orders", headers=customer["headers"])
    assert checked_out.status_code == 201
    assert checked_out.json()["total_amount"] == "150.00"
    assert client.get("/api/cart", headers=customer["headers"]).json()["items"] == []
    with SessionLocal() as db:
        assert db.get(Product, product).stock_quantity == 7


def test_user_cannot_view_another_users_order(client, customer, product):
    client.post("/api/cart/items", headers=customer["headers"], json={"product_id": product, "quantity": 1})
    order_id = client.post("/api/orders", headers=customer["headers"]).json()["id"]
    other = register(client, "other@example.com").json()
    headers = {"Authorization": f"Bearer {other['access_token']}"}
    assert client.get(f"/api/orders/{order_id}", headers=headers).status_code == 404
    assert client.get("/api/orders", headers=headers).json() == []


def test_checkout_empty_cart_rejected(client, customer):
    assert client.post("/api/orders", headers=customer["headers"]).status_code == 400
