from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models import Cart, CartItem, Product, User
from app.observability.logging import security_event
from app.schemas.api import CartItemCreate, CartItemOut, CartItemUpdate, CartOut

router = APIRouter(prefix="/cart", tags=["cart"])


def load_cart(db: Session, user_id: int) -> Cart:
    cart = db.execute(
        select(Cart)
        .where(Cart.user_id == user_id)
        .options(joinedload(Cart.items).joinedload(CartItem.product))
        .execution_options(populate_existing=True)
    ).unique().scalar_one_or_none()
    if not cart:
        cart = Cart(user_id=user_id)
        db.add(cart)
        db.commit()
        db.refresh(cart)
    return cart


def cart_out(cart: Cart) -> CartOut:
    items = [
        CartItemOut(
            id=item.id,
            product_id=item.product_id,
            quantity=item.quantity,
            product=item.product,
            line_total=item.product.price * item.quantity,
        )
        for item in cart.items
    ]
    return CartOut(id=cart.id, items=items, total=sum((item.line_total for item in items), Decimal("0.00")))


@router.get("", response_model=CartOut)
def get_cart(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return cart_out(load_cart(db, user.id))


@router.post("/items", response_model=CartOut, status_code=status.HTTP_201_CREATED)
def add_item(data: CartItemCreate, request: Request, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    product = db.scalar(select(Product).where(Product.id == data.product_id, Product.active.is_(True)))
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    cart = load_cart(db, user.id)
    item = next((entry for entry in cart.items if entry.product_id == product.id), None)
    requested = data.quantity + (item.quantity if item else 0)
    if requested > product.stock_quantity:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Requested quantity exceeds available stock")
    if item:
        item.quantity = requested
    else:
        db.add(CartItem(cart_id=cart.id, product_id=product.id, quantity=data.quantity))
    db.commit()
    security_event(request, "CART_ITEM_ADDED", "Product added to cart", user_id=user.id, user_role=user.role.value)
    return cart_out(load_cart(db, user.id))


@router.put("/items/{item_id}", response_model=CartOut)
def update_item(item_id: int, data: CartItemUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    item = db.scalar(select(CartItem).join(Cart).where(CartItem.id == item_id, Cart.user_id == user.id).options(joinedload(CartItem.product)))
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cart item not found")
    if data.quantity > item.product.stock_quantity:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Requested quantity exceeds available stock")
    item.quantity = data.quantity
    db.commit()
    return cart_out(load_cart(db, user.id))


@router.delete("/items/{item_id}", response_model=CartOut)
def remove_item(item_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    item = db.scalar(select(CartItem).join(Cart).where(CartItem.id == item_id, Cart.user_id == user.id))
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cart item not found")
    db.delete(item)
    db.commit()
    return cart_out(load_cart(db, user.id))


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
def clear_cart(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    cart = load_cart(db, user.id)
    for item in cart.items:
        db.delete(item)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
