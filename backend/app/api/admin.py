from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.api.deps import require_admin
from app.db.session import get_db
from app.models import Order, Product, User
from app.observability.logging import security_event
from app.schemas.api import AdminUserOut, OrderOut, ProductCreate, ProductOut, ProductUpdate

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/products", response_model=list[ProductOut])
def products(_: User = Depends(require_admin), db: Session = Depends(get_db)):
    return list(db.scalars(select(Product).order_by(Product.name)))


@router.post("/products", response_model=ProductOut, status_code=status.HTTP_201_CREATED)
def create_product(data: ProductCreate, request: Request, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    product = Product(**data.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    security_event(request, "ADMIN_PRODUCT_CREATED", "Admin created product", user_id=admin.id, user_role=admin.role.value)
    return product


@router.put("/products/{product_id}", response_model=ProductOut)
def update_product(product_id: int, data: ProductUpdate, request: Request, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    product = db.get(Product, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    for key, value in data.model_dump().items():
        setattr(product, key, value)
    db.commit()
    db.refresh(product)
    security_event(request, "ADMIN_PRODUCT_UPDATED", "Admin updated product", user_id=admin.id, user_role=admin.role.value)
    return product


@router.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def disable_product(product_id: int, request: Request, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    product = db.get(Product, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    product.active = False
    db.commit()
    security_event(request, "ADMIN_PRODUCT_DISABLED", "Admin disabled product", user_id=admin.id, user_role=admin.role.value)


@router.get("/orders", response_model=list[OrderOut])
def orders(_: User = Depends(require_admin), db: Session = Depends(get_db)):
    return list(db.scalars(select(Order).options(joinedload(Order.items)).order_by(Order.created_at.desc())).unique())


@router.get("/users", response_model=list[AdminUserOut])
def users(request: Request, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    results = list(db.scalars(select(User).order_by(User.created_at.desc())))
    security_event(request, "ADMIN_USERS_VIEWED", "Administrator viewed account directory", user_id=admin.id, user_role=admin.role.value)
    return results
