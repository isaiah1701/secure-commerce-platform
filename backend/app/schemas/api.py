import re
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models import OrderStatus, UserRole


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=10, max_length=128)
    first_name: str = Field(min_length=1, max_length=80)
    last_name: str = Field(min_length=1, max_length=80)

    @field_validator("password")
    @classmethod
    def strong_password(cls, value: str) -> str:
        if not (re.search(r"[A-Z]", value) and re.search(r"[a-z]", value) and re.search(r"\d", value) and re.search(r"[^A-Za-z0-9]", value)):
            raise ValueError("Password must include upper, lower, number, and special characters")
        return value


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    email: EmailStr
    first_name: str
    last_name: str
    role: UserRole
    created_at: datetime
    last_login_at: datetime | None
    is_active: bool


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class ProductBase(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    description: str = Field(min_length=5, max_length=3000)
    category: str = Field(min_length=2, max_length=80)
    price: Decimal = Field(gt=0, max_digits=10, decimal_places=2)
    stock_quantity: int = Field(ge=0, le=1_000_000)
    image_url: str | None = Field(default=None, max_length=500)
    active: bool = True


class ProductCreate(ProductBase):
    pass


class ProductUpdate(ProductBase):
    pass


class ProductOut(ProductBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime
    updated_at: datetime


class CartItemCreate(BaseModel):
    product_id: int = Field(gt=0)
    quantity: int = Field(gt=0, le=100)


class CartItemUpdate(BaseModel):
    quantity: int = Field(gt=0, le=100)


class CartItemOut(BaseModel):
    id: int
    product_id: int
    quantity: int
    product: ProductOut
    line_total: Decimal


class CartOut(BaseModel):
    id: int
    items: list[CartItemOut]
    total: Decimal


class OrderItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    product_id: int
    product_name: str
    unit_price: Decimal
    quantity: int


class OrderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    status: OrderStatus
    total_amount: Decimal
    created_at: datetime
    updated_at: datetime
    items: list[OrderItemOut]


class AdminUserOut(UserOut):
    failed_login_attempts: int
    locked_until: datetime | None
