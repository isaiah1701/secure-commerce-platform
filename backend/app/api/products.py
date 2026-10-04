from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import Product
from app.schemas.api import ProductOut

router = APIRouter(prefix="/products", tags=["products"])


@router.get("", response_model=list[ProductOut])
def list_products(
    search: str | None = Query(default=None, min_length=1, max_length=100),
    category: str | None = Query(default=None, min_length=1, max_length=80),
    db: Session = Depends(get_db),
):
    query = select(Product).where(Product.active.is_(True)).order_by(Product.name)
    if search:
        term = f"%{search.strip()}%"
        query = query.where(or_(Product.name.ilike(term), Product.description.ilike(term)))
    if category:
        query = query.where(func.lower(Product.category) == category.strip().lower())
    return list(db.scalars(query))


@router.get("/{product_id}", response_model=ProductOut)
def get_product(product_id: int, db: Session = Depends(get_db)):
    product = db.scalar(select(Product).where(Product.id == product_id, Product.active.is_(True)))
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    return product
