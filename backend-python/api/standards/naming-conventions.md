# Naming Conventions

## Overview

This guide covers naming conventions for Python backend projects, following PEP 8 with project-specific additions.

## File Naming

| Type | Convention | Example |
|------|------------|---------|
| Python modules | `snake_case.py` | `product_service.py` |
| Test files | `test_<module>.py` | `test_product_service.py` |
| Configuration | `snake_case.py` or `.env` | `config.py`, `.env` |
| Alembic migrations | Auto-generated | `2024_01_15_abc123_add_products.py` |

### Directory Structure

```
src/
├── api/
│   ├── routes/
│   │   ├── products.py        # Plural for resource routes
│   │   ├── users.py
│   │   └── health.py          # Singular for utilities
│   └── dependencies.py        # Shared dependencies
├── services/
│   ├── product_service.py     # Singular noun + _service
│   ├── user_service.py
│   └── auth_service.py
├── models/
│   ├── product.py             # Singular, matches model name
│   ├── user.py
│   └── base.py
├── schemas/
│   ├── product.py             # Matches model file name
│   ├── user.py
│   └── common.py              # Shared schemas
└── core/
    ├── config.py
    ├── database.py
    ├── security.py
    └── exceptions.py
```

## Python Naming

### Variables and Functions

```python
# Variables: snake_case
user_count = 10
is_active = True
product_ids = [uuid4(), uuid4()]

# Functions: snake_case, verb + noun
def get_user_by_id(user_id: UUID) -> User: ...
def create_product(data: ProductCreate) -> Product: ...
def validate_email(email: str) -> bool: ...
def send_notification(user_id: UUID, message: str) -> None: ...

# Private functions: leading underscore
def _calculate_discount(price: Decimal, rate: float) -> Decimal: ...
def _validate_internal(data: dict) -> bool: ...
```

### Classes

```python
# Classes: PascalCase
class ProductService: ...
class UserRepository: ...
class AuthenticationError(Exception): ...

# SQLAlchemy models: PascalCase, singular
class Product(Base): ...
class User(Base): ...
class OrderItem(Base): ...

# Pydantic schemas: PascalCase with suffix
class ProductCreate(BaseModel): ...      # For creation
class ProductUpdate(BaseModel): ...      # For updates
class ProductResponse(BaseModel): ...    # For responses
class ProductListResponse(BaseModel): ... # For list responses
```

### Constants

```python
# Constants: UPPER_SNAKE_CASE
MAX_RETRY_ATTEMPTS = 3
DEFAULT_PAGE_SIZE = 20
API_VERSION = "v1"

# In settings/config
class Settings(BaseSettings):
    database_url: PostgresDsn
    jwt_secret_key: SecretStr
    max_connections: int = 10
```

### Enums

```python
from enum import Enum

# Enum class: PascalCase
# Enum values: UPPER_SNAKE_CASE
class OrderStatus(str, Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"

class UserRole(str, Enum):
    ADMIN = "admin"
    MANAGER = "manager"
    USER = "user"
```

## FastAPI Naming

### Routes

```python
# Router: lowercase resource name
router = APIRouter(prefix="/products", tags=["products"])

# Endpoints: verb + noun or descriptive action
@router.get("")
async def list_products(): ...          # List resources

@router.get("/{product_id}")
async def get_product(): ...            # Get single resource

@router.post("")
async def create_product(): ...         # Create resource

@router.patch("/{product_id}")
async def update_product(): ...         # Partial update

@router.put("/{product_id}")
async def replace_product(): ...        # Full replacement

@router.delete("/{product_id}")
async def delete_product(): ...         # Delete resource

# Custom actions
@router.post("/{product_id}/publish")
async def publish_product(): ...

@router.get("/{product_id}/reviews")
async def list_product_reviews(): ...
```

### Path Parameters

```python
# Use snake_case, descriptive names
@router.get("/{product_id}")
async def get_product(product_id: UUID): ...

@router.get("/{category_id}/products")
async def list_category_products(category_id: UUID): ...
```

### Query Parameters

```python
# snake_case, descriptive
@router.get("")
async def list_products(
    skip: int = Query(default=0),
    limit: int = Query(default=20),
    category_id: UUID | None = Query(default=None),
    is_active: bool = Query(default=True),
    sort_by: str = Query(default="created_at"),
    sort_order: str = Query(default="desc"),
): ...
```

### Dependencies

```python
# Dependency functions: get_* or require_*
def get_db() -> AsyncGenerator[AsyncSession, None]: ...
def get_current_user() -> User: ...
def get_product_service() -> ProductService: ...

def require_admin() -> User: ...
def require_permission(permission: str) -> Callable: ...
```

## SQLAlchemy Naming

### Models

```python
# Model class: PascalCase, singular
class Product(Base):
    # Table name: snake_case, plural
    __tablename__ = "products"

    # Columns: snake_case
    id: Mapped[UUID] = mapped_column(primary_key=True)
    product_name: Mapped[str] = mapped_column(String(200))
    created_at: Mapped[datetime] = mapped_column()
    is_active: Mapped[bool] = mapped_column(default=True)

    # Foreign keys: <related_model>_id
    category_id: Mapped[UUID] = mapped_column(ForeignKey("categories.id"))
    created_by: Mapped[UUID] = mapped_column(ForeignKey("users.id"))

    # Relationships: descriptive name
    category: Mapped["Category"] = relationship(back_populates="products")
    reviews: Mapped[list["Review"]] = relationship(back_populates="product")
```

### Indexes and Constraints

```python
class Product(Base):
    __tablename__ = "products"

    __table_args__ = (
        # Index: ix_<table>_<column(s)>
        Index("ix_products_category_id", "category_id"),
        Index("ix_products_created_at", "created_at"),

        # Unique constraint: uq_<table>_<column(s)>
        UniqueConstraint("sku", name="uq_products_sku"),

        # Foreign key: fk_<table>_<column>_<referenced_table>
        # (Usually auto-generated)

        # Check constraint: ck_<table>_<description>
        CheckConstraint("price > 0", name="ck_products_positive_price"),
    )
```

## Pydantic Naming

### Schema Classes

```python
# Base schema (shared fields)
class ProductBase(BaseModel):
    name: str
    price: Decimal

# Create schema (input for POST)
class ProductCreate(ProductBase):
    sku: str

# Update schema (input for PATCH)
class ProductUpdate(BaseModel):
    name: str | None = None
    price: Decimal | None = None

# Response schema (output)
class ProductResponse(ProductBase):
    id: UUID
    created_at: datetime

# List response
class ProductListResponse(BaseModel):
    items: list[ProductResponse]
    total: int
```

### Field Names

```python
class UserResponse(BaseModel):
    # snake_case for all fields
    user_id: UUID
    email_address: str
    first_name: str
    last_name: str
    is_active: bool
    created_at: datetime
    updated_at: datetime | None

    # Use aliases for external APIs
    model_config = ConfigDict(populate_by_name=True)

    external_id: str = Field(alias="externalId")  # For external JSON
```

## Service Naming

### Classes

```python
# <Domain>Service
class ProductService: ...
class UserService: ...
class AuthService: ...
class OrderService: ...
class NotificationService: ...
```

### Methods

```python
class ProductService:
    # CRUD operations
    async def get_by_id(self, product_id: UUID) -> Product: ...
    async def get_by_sku(self, sku: str) -> Product | None: ...
    async def list(self, skip: int, limit: int) -> tuple[list[Product], int]: ...
    async def create(self, data: ProductCreate) -> Product: ...
    async def update(self, product_id: UUID, data: ProductUpdate) -> Product: ...
    async def delete(self, product_id: UUID) -> None: ...

    # Business operations
    async def publish(self, product_id: UUID) -> Product: ...
    async def archive(self, product_id: UUID) -> Product: ...
    async def bulk_update_prices(self, category_id: UUID, multiplier: Decimal) -> int: ...

    # Private methods
    async def _validate_sku(self, sku: str) -> bool: ...
    async def _notify_subscribers(self, product: Product) -> None: ...
```

## Exception Naming

```python
# Custom exceptions: PascalCase, end with Error
class NotFoundError(AppError): ...
class ConflictError(AppError): ...
class ValidationError(AppError): ...
class AuthenticationError(AppError): ...
class AuthorizationError(AppError): ...
class ExternalServiceError(AppError): ...

# Specific errors
class ProductNotFoundError(NotFoundError): ...
class DuplicateSKUError(ConflictError): ...
class InvalidPriceError(ValidationError): ...
```

## Test Naming

```python
# Test files: test_<module>.py
# test_product_service.py

# Test classes: Test<Class>
class TestProductService:

    # Test methods: test_<method>_<scenario>_<expected>
    async def test_get_by_id_existing_returns_product(self): ...
    async def test_get_by_id_nonexistent_raises_not_found(self): ...
    async def test_create_valid_data_creates_product(self): ...
    async def test_create_duplicate_sku_raises_conflict(self): ...

# Fixtures: descriptive noun
@pytest.fixture
def product_service(): ...

@pytest.fixture
def sample_product(): ...

@pytest.fixture
def mock_db(): ...
```

## Comparison with .NET

| .NET | Python |
|------|--------|
| `PascalCase` methods | `snake_case` functions |
| `IProductService` interface | `ProductService` (no interface prefix) |
| `ProductDto` | `ProductResponse` or `ProductCreate` |
| `ProductEntity` | `Product` (no suffix) |
| `_privateField` | `_private_variable` |
| `ProductController` | `products.py` router |
| `GetProductById` | `get_product_by_id` or `get_by_id` |

## Summary

| Type | Convention | Example |
|------|------------|---------|
| File | `snake_case.py` | `product_service.py` |
| Variable | `snake_case` | `user_count` |
| Function | `snake_case` | `get_user_by_id` |
| Class | `PascalCase` | `ProductService` |
| Constant | `UPPER_SNAKE_CASE` | `MAX_RETRIES` |
| Enum value | `UPPER_SNAKE_CASE` | `OrderStatus.PENDING` |
| Table name | `snake_case`, plural | `products` |
| Column name | `snake_case` | `created_at` |
| Foreign key | `<model>_id` | `category_id` |
| Index | `ix_<table>_<column>` | `ix_products_sku` |
| Route prefix | `/lowercase-plural` | `/products` |
| Test file | `test_<module>.py` | `test_product_service.py` |
| Test method | `test_<scenario>` | `test_create_valid_data_succeeds` |
