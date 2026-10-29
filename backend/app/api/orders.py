from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models import Cart, CartItem, Order, OrderItem, OrderStatus, Product, User
from app.observability.logging import security_event
from app.observability.metrics import ORDERS_CREATED
from app.schemas.api import OrderOut

router = APIRouter(prefix="/orders", tags=["orders"])


@router.post("", response_model=OrderOut, status_code=status.HTTP_201_CREATED)
def checkout(request: Request, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    cart = db.execute(select(Cart).where(Cart.user_id == user.id).options(joinedload(Cart.items).joinedload(CartItem.product))).unique().scalar_one_or_none()
    if not cart or not cart.items:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cart is empty")

    total = Decimal("0.00")
    snapshots = []
    for cart_item in cart.items:
        product = db.scalar(select(Product).where(Product.id == cart_item.product_id).with_for_update())
        if not product or not product.active or product.stock_quantity < cart_item.quantity:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Insufficient stock for {cart_item.product.name}")
        total += product.price * cart_item.quantity
        snapshots.append((product, cart_item.quantity))

    order = Order(user_id=user.id, status=OrderStatus.confirmed, total_amount=total)
    db.add(order)
    db.flush()
    for product, quantity in snapshots:
        db.add(OrderItem(order_id=order.id, product_id=product.id, product_name=product.name, unit_price=product.price, quantity=quantity))
        product.stock_quantity -= quantity
    for item in cart.items:
        db.delete(item)
    db.commit()
    order = db.execute(select(Order).where(Order.id == order.id).options(joinedload(Order.items))).unique().scalar_one()
    ORDERS_CREATED.inc()
    security_event(request, "ORDER_CREATED", "Order created", user_id=user.id, user_role=user.role.value)
    return order


@router.get("", response_model=list[OrderOut])
def list_orders(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return list(db.scalars(select(Order).where(Order.user_id == user.id).options(joinedload(Order.items)).order_by(Order.created_at.desc())).unique())


@router.get("/{order_id}", response_model=OrderOut)
def get_order(order_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    order = db.execute(select(Order).where(Order.id == order_id, Order.user_id == user.id).options(joinedload(Order.items))).unique().scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    return order
