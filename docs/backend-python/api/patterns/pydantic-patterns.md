# Pydantic Patterns

## Overview

Pydantic v2 is used for data validation, serialization, and settings management. It replaces FluentValidation (validation) and AutoMapper (mapping) from .NET.

## Schema Organization

```
src/schemas/
├── __init__.py
├── common.py          # Shared schemas (pagination, errors)
├── product.py         # ProductCreate, ProductUpdate, ProductResponse
├── user.py            # UserCreate, UserResponse, etc.
└── auth.py            # TokenPayload, LoginRequest, etc.
```

## Basic Patterns

### Request/Response Schemas

```python
# src/schemas/product.py
from datetime import datetime
from decimal import Decimal
from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict


class ProductBase(BaseModel):
    """Shared fields for product schemas."""
    name: str = Field(min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=2000)
    price: Decimal = Field(gt=0, decimal_places=2)
    sku: str = Field(pattern=r"^[A-Z0-9-]+$", max_length=50)


class ProductCreate(ProductBase):
    """Schema for creating a product."""
    category_id: UUID


class ProductUpdate(BaseModel):
    """Schema for updating a product (all fields optional)."""
    name: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    price: Decimal | None = Field(default=None, gt=0)
    category_id: UUID | None = None


class ProductResponse(ProductBase):
    """Schema for product API responses."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    category_id: UUID
    created_at: datetime
    updated_at: datetime | None = None
```

### Converting from ORM Models

```python
# Using from_attributes (was orm_mode in v1)
class ProductResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str

# Usage
product = await db.get(Product, product_id)
response = ProductResponse.model_validate(product)
```

## Validation

### Field Constraints

```python
from pydantic import Field

class ProductCreate(BaseModel):
    # String constraints
    name: str = Field(min_length=1, max_length=200)
    sku: str = Field(pattern=r"^[A-Z]{2}-\d{6}$")  # e.g., "AB-123456"

    # Numeric constraints
    price: Decimal = Field(gt=0, le=999999.99, decimal_places=2)
    quantity: int = Field(ge=0, lt=10000)

    # Optional with default
    description: str | None = Field(default=None, max_length=2000)

    # List constraints
    tags: list[str] = Field(default_factory=list, max_length=10)
```

### Custom Validators

```python
from pydantic import BaseModel, field_validator, model_validator


class OrderCreate(BaseModel):
    items: list[OrderItemCreate]
    discount_code: str | None = None

    @field_validator("items")
    @classmethod
    def validate_items_not_empty(cls, v: list) -> list:
        if not v:
            raise ValueError("Order must have at least one item")
        return v

    @field_validator("discount_code")
    @classmethod
    def validate_discount_code(cls, v: str | None) -> str | None:
        if v is not None:
            return v.upper().strip()
        return v

    @model_validator(mode="after")
    def validate_order(self) -> "OrderCreate":
        """Cross-field validation."""
        total = sum(item.quantity * item.price for item in self.items)
        if total < 10:
            raise ValueError("Minimum order value is $10")
        return self
```

### Async Validators (Service Layer)

Pydantic validators are synchronous. For async validation (e.g., database checks), validate in the service:

```python
# src/services/product_service.py
class ProductService:
    async def create(self, data: ProductCreate) -> Product:
        # Async validation
        if await self._sku_exists(data.sku):
            raise ConflictError(f"SKU {data.sku} already exists")

        if not await self._category_exists(data.category_id):
            raise ValidationError(f"Category {data.category_id} not found")

        return await self._create(data)
```

## Nested Models

```python
class Address(BaseModel):
    street: str
    city: str
    country: str = Field(pattern=r"^[A-Z]{2}$")  # ISO country code


class OrderItem(BaseModel):
    product_id: UUID
    quantity: int = Field(gt=0)
    price: Decimal


class OrderCreate(BaseModel):
    shipping_address: Address
    billing_address: Address | None = None  # Optional, defaults to shipping
    items: list[OrderItem] = Field(min_length=1)

    @model_validator(mode="after")
    def set_billing_address(self) -> "OrderCreate":
        if self.billing_address is None:
            self.billing_address = self.shipping_address
        return self
```

## Enums

```python
from enum import Enum


class OrderStatus(str, Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"


class OrderResponse(BaseModel):
    id: UUID
    status: OrderStatus  # Validates against enum values


# Request with enum
class OrderStatusUpdate(BaseModel):
    status: OrderStatus
```

## Generic Schemas

```python
from typing import Generic, TypeVar
from pydantic import BaseModel

T = TypeVar("T")


class PaginatedResponse(BaseModel, Generic[T]):
    """Generic paginated response."""
    items: list[T]
    total: int
    skip: int
    limit: int

    @property
    def has_more(self) -> bool:
        return self.skip + len(self.items) < self.total


# Usage
class ProductListResponse(PaginatedResponse[ProductResponse]):
    pass
```

## Settings Management

```python
# src/core/config.py
from functools import lru_cache
from pydantic import Field, PostgresDsn, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Application
    app_name: str = "My API"
    debug: bool = False
    environment: str = "development"

    # Database
    database_url: PostgresDsn

    # Security
    jwt_secret_key: SecretStr
    jwt_algorithm: str = "HS256"
    jwt_expiration_minutes: int = 30

    # OAuth
    google_client_id: str | None = None
    google_client_secret: SecretStr | None = None

    # External Services
    langfuse_public_key: str | None = None
    langfuse_secret_key: SecretStr | None = None
    langfuse_host: str = "https://cloud.langfuse.com"

    # Rate Limiting
    rate_limit_requests: int = 100
    rate_limit_window_seconds: int = 60


@lru_cache
def get_settings() -> Settings:
    """Cached settings instance."""
    return Settings()
```

### Nested Settings

```python
class DatabaseSettings(BaseModel):
    url: PostgresDsn
    pool_size: int = 5
    max_overflow: int = 10
    echo: bool = False


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_nested_delimiter="__")

    database: DatabaseSettings

# Environment variables:
# DATABASE__URL=postgresql+asyncpg://...
# DATABASE__POOL_SIZE=10
```

## Serialization Control

### Excluding Fields

```python
class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: str
    # password_hash not included - excluded by not defining it


class UserInternal(BaseModel):
    """Internal use only - includes sensitive fields."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: str
    password_hash: str

    def to_response(self) -> UserResponse:
        return UserResponse.model_validate(self)
```

### Computed Fields

```python
from pydantic import computed_field


class OrderResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    items: list[OrderItemResponse]

    @computed_field
    @property
    def total(self) -> Decimal:
        return sum(item.quantity * item.price for item in self.items)

    @computed_field
    @property
    def item_count(self) -> int:
        return sum(item.quantity for item in self.items)
```

### Field Aliases

```python
class ExternalAPIResponse(BaseModel):
    """Map external API field names to internal names."""
    model_config = ConfigDict(populate_by_name=True)

    product_id: UUID = Field(alias="productId")
    display_name: str = Field(alias="displayName")
    unit_price: Decimal = Field(alias="unitPrice")


# Parse external response
external_data = {"productId": "...", "displayName": "...", "unitPrice": 9.99}
parsed = ExternalAPIResponse.model_validate(external_data)

# Access with Python names
print(parsed.product_id, parsed.display_name)
```

### Custom Serialization

```python
from pydantic import field_serializer


class ProductResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    price: Decimal
    created_at: datetime

    @field_serializer("price")
    def serialize_price(self, price: Decimal) -> str:
        return f"${price:.2f}"

    @field_serializer("created_at")
    def serialize_datetime(self, dt: datetime) -> str:
        return dt.isoformat()
```

## Type Coercion

```python
from pydantic import BeforeValidator
from typing import Annotated


def parse_uuid(value: str | UUID) -> UUID:
    if isinstance(value, UUID):
        return value
    return UUID(value)


FlexibleUUID = Annotated[UUID, BeforeValidator(parse_uuid)]


class ProductQuery(BaseModel):
    product_id: FlexibleUUID  # Accepts string or UUID
```

## Comparison with .NET

| .NET | Pydantic |
|------|----------|
| FluentValidation `RuleFor` | `Field()` constraints + `@field_validator` |
| `[Required]` | Field without default |
| `[StringLength]` | `Field(min_length, max_length)` |
| `[Range]` | `Field(gt, lt, ge, le)` |
| `[RegularExpression]` | `Field(pattern=...)` |
| AutoMapper profiles | `from_attributes=True` + `model_validate` |
| `IOptions<T>` | `pydantic_settings.BaseSettings` |
| Record DTOs | Pydantic `BaseModel` |

## Best Practices

### 1. Separate Request and Response Schemas

```python
# Good - explicit schemas
class ProductCreate(BaseModel): ...
class ProductUpdate(BaseModel): ...
class ProductResponse(BaseModel): ...

# Avoid - one schema for everything
class Product(BaseModel): ...  # Used for create, update, and response
```

### 2. Use Base Classes for Shared Fields

```python
# Good - DRY
class ProductBase(BaseModel):
    name: str
    price: Decimal

class ProductCreate(ProductBase):
    sku: str

class ProductResponse(ProductBase):
    id: UUID
```

### 3. Validate Early

```python
# Good - validation at API boundary
@router.post("")
async def create(data: ProductCreate):  # Validated here
    return await service.create(data)

# Avoid - late validation
@router.post("")
async def create(data: dict):  # No validation
    validated = ProductCreate(**data)  # Validation in handler
```

### 4. Use Strict Types for IDs

```python
# Good - type-safe
class ProductQuery(BaseModel):
    product_id: UUID  # Must be valid UUID

# Avoid - stringly typed
class ProductQuery(BaseModel):
    product_id: str  # Could be anything
```

### 5. Document with Field Descriptions

```python
class ProductCreate(BaseModel):
    name: str = Field(
        min_length=1,
        max_length=200,
        description="Product display name",
        examples=["Premium Widget"],
    )
    price: Decimal = Field(
        gt=0,
        description="Price in USD",
        examples=[29.99],
    )
```
