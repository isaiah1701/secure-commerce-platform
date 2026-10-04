import os
from decimal import Decimal

from sqlalchemy import func, select

from app.auth.security import hash_password
from app.db.session import SessionLocal
from app.models import Cart, Product, User, UserRole

PRODUCTS = [
    ("Wireless Headphones", "Noise-cancelling over-ear headphones with a 30-hour battery.", "Electronics", "129.99", 35, "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=900"),
    ("Mechanical Keyboard", "Tactile hot-swappable keyboard with warm white backlighting.", "Electronics", "89.00", 28, "https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=900"),
    ("USB-C Hub", "Compact seven-port hub for modern laptops and tablets.", "Electronics", "49.50", 62, "https://images.unsplash.com/photo-1625842268584-8f3296236761?w=900"),
    ("Smart Watch", "Everyday fitness tracking, notifications, and sleep insights.", "Electronics", "179.00", 21, "https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=900"),
    ("Portable Speaker", "Water-resistant Bluetooth speaker with rich, balanced sound.", "Electronics", "74.95", 44, "https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=900"),
    ("Classic Hoodie", "Heavyweight organic cotton hoodie with a relaxed fit.", "Clothing", "58.00", 51, "https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=900"),
    ("Everyday T-Shirt", "Soft midweight cotton tee designed for daily wear.", "Clothing", "24.00", 90, "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=900"),
    ("Rain Jacket", "Lightweight waterproof shell with sealed seams.", "Clothing", "112.00", 18, "https://images.unsplash.com/photo-1544966503-7cc5ac882d5f?w=900"),
    ("Merino Beanie", "Warm, breathable beanie made from responsibly sourced wool.", "Clothing", "29.50", 47, "https://images.unsplash.com/photo-1576871337632-b9aef4c17ab9?w=900"),
    ("Canvas Overshirt", "A versatile layer in durable brushed cotton canvas.", "Clothing", "67.00", 26, "https://images.unsplash.com/photo-1598033129183-c4f50c736f10?w=900"),
    ("Desk Lamp", "Dimmable LED task light with adjustable color temperature.", "Home", "45.00", 38, "https://images.unsplash.com/photo-1507473885765-e6ed057f782c?w=900"),
    ("Ceramic Planter", "Hand-finished stoneware planter with drainage tray.", "Home", "32.00", 33, "https://images.unsplash.com/photo-1485955900006-10f4d324d411?w=900"),
    ("Wool Throw", "Soft woven throw blanket in a calm neutral palette.", "Home", "79.00", 17, "https://images.unsplash.com/photo-1580301762395-21ce84d00bc6?w=900"),
    ("Pour-over Set", "Glass carafe and reusable stainless-steel coffee filter.", "Home", "42.50", 24, "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=900"),
    ("Scented Candle", "Cedar, bergamot, and amber in a reusable glass vessel.", "Home", "26.00", 55, "https://images.unsplash.com/photo-1603006905003-be475563bc59?w=900"),
    ("City Backpack", "Weatherproof 22-litre backpack with a padded laptop sleeve.", "Accessories", "84.00", 31, "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=900"),
    ("Laptop Stand", "Foldable aluminium stand for an ergonomic desk setup.", "Accessories", "39.00", 48, "https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=900"),
    ("Leather Card Holder", "Slim vegetable-tanned leather wallet with four slots.", "Accessories", "36.00", 40, "https://images.unsplash.com/photo-1627123424574-724758594e93?w=900"),
    ("Insulated Bottle", "Double-wall stainless bottle that keeps drinks cold all day.", "Accessories", "31.50", 73, "https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=900"),
    ("Travel Organizer", "Compact recycled-fabric pouch for cables and essentials.", "Accessories", "28.00", 45, "https://images.unsplash.com/photo-1553531889-56d5b8272d2a?w=900"),
]


def seed() -> None:
    with SessionLocal() as db:
        if not db.scalar(select(func.count(Product.id))):
            for name, description, category, price, stock, image_url in PRODUCTS:
                db.add(Product(name=name, description=description, category=category, price=Decimal(price), stock_quantity=stock, image_url=image_url))

        demo_password = os.getenv("DEMO_PASSWORD", "DemoPass!2026")
        admin_password = os.getenv("ADMIN_PASSWORD", "AdminPass!2026")
        for email, password, first, last, role in (
            ("customer@example.com", demo_password, "Demo", "Customer", UserRole.customer),
            ("admin@example.com", admin_password, "Store", "Admin", UserRole.admin),
        ):
            if not db.scalar(select(User).where(User.email == email)):
                user = User(email=email, password_hash=hash_password(password), first_name=first, last_name=last, role=role)
                db.add(user)
                db.flush()
                db.add(Cart(user_id=user.id))
        db.commit()
    print("Seed complete: products and local demo accounts are ready.")


if __name__ == "__main__":
    seed()
