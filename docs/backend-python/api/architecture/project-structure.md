# Project Structure

## Overview

This project follows a layered architecture optimized for FastAPI applications. Unlike .NET Clean Architecture with strict project boundaries, Python uses a single package with clear module separation.

## Directory Layout

```
project-root/
├── src/
│   ├── __init__.py
│   ├── main.py                     # FastAPI app factory & startup
│   │
│   ├── api/                        # HTTP layer (like Controllers in .NET)
│   │   ├── __init__.py
│   │   ├── dependencies.py         # Shared Depends() factories
│   │   └── routes/                 # Route handlers by domain
│   │       ├── __init__.py
│   │       ├── products.py
│   │       ├── users.py
│   │       └── health.py
│   │
│   ├── services/                   # Business logic layer
│   │   ├── __init__.py
│   │   ├── product_service.py
│   │   ├── user_service.py
│   │   └── auth_service.py
│   │
│   ├── models/                     # SQLAlchemy models (like Entities in .NET)
│   │   ├── __init__.py
│   │   ├── base.py                 # Base model with common fields
│   │   ├── product.py
│   │   ├── user.py
│   │   └── mixins.py               # Reusable model mixins
│   │
│   ├── schemas/                    # Pydantic models (like DTOs in .NET)
│   │   ├── __init__.py
│   │   ├── product.py              # ProductCreate, ProductResponse, etc.
│   │   ├── user.py
│   │   └── common.py               # Shared schemas (Pagination, etc.)
│   │
│   ├── core/                       # Application infrastructure
│   │   ├── __init__.py
│   │   ├── config.py               # Settings via pydantic-settings
│   │   ├── database.py             # AsyncSession factory
│   │   ├── security.py             # JWT, password hashing
│   │   └── exceptions.py           # Custom exception classes
│   │
│   └── utils/                      # Shared utilities
│       ├── __init__.py
│       ├── logging.py              # structlog configuration
│       └── datetime.py             # Timezone utilities
│
├── tests/
│   ├── __init__.py
│   ├── conftest.py                 # Shared pytest fixtures
│   ├── unit/                       # Unit tests (mocked dependencies)
│   │   ├── __init__.py
│   │   ├── services/
│   │   └── api/
│   └── integration/                # Integration tests (real DB)
│       ├── __init__.py
│       ├── conftest.py             # DB fixtures
│       └── api/
│
├── migrations/                     # Alembic migrations
│   ├── versions/
│   ├── env.py
│   └── script.py.mako
│
├── pyproject.toml                  # Project config, dependencies
├── alembic.ini                     # Alembic config
├── .env.example                    # Environment template
└── README.md
```

## Layer Responsibilities

### API Layer (`src/api/`)

**Purpose**: HTTP request handling, input validation, response formatting

**Responsibilities**:

- Define routes and HTTP methods
- Parse and validate request data (via Pydantic)
- Call services for business logic
- Format responses
- Handle HTTP-specific concerns (status codes, headers)

**Does NOT**:

- Contain business logic
- Access database directly
- Handle authentication logic (delegated to dependencies)

```python
# src/api/routes/products.py
from fastapi import APIRouter, Depends, status
from src.schemas.product import ProductCreate, ProductResponse
from src.services.product_service import ProductService
from src.api.dependencies import get_product_service, get_current_user

router = APIRouter(prefix="/products", tags=["products"])

@router.post("", status_code=status.HTTP_201_CREATED)
async def create_product(
    data: ProductCreate,
    service: ProductService = Depends(get_product_service),
    current_user: User = Depends(get_current_user),
) -> ProductResponse:
    product = await service.create(data, created_by=current_user.id)
    return ProductResponse.model_validate(product)
```

### Services Layer (`src/services/`)

**Purpose**: Business logic and orchestration

**Responsibilities**:

- Implement business rules
- Coordinate database operations
- Call external services
- Emit events/logs

**Does NOT**:

- Handle HTTP concerns
- Know about request/response formats
- Manage database sessions (receives session via DI)

```python
# src/services/product_service.py
from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from src.models.product import Product
from src.schemas.product import ProductCreate
from src.core.exceptions import NotFoundError

class ProductService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(self, data: ProductCreate, created_by: UUID) -> Product:
        product = Product(**data.model_dump(), created_by=created_by)
        self.db.add(product)
        await self.db.commit()
        await self.db.refresh(product)
        return product

    async def get_by_id(self, product_id: UUID) -> Product:
        result = await self.db.execute(
            select(Product).where(Product.id == product_id)
        )
        product = result.scalar_one_or_none()
        if not product:
            raise NotFoundError(f"Product {product_id} not found")
        return product
```

### Models Layer (`src/models/`)

**Purpose**: Database schema definition (SQLAlchemy ORM)

**Responsibilities**:

- Define table structure
- Define relationships
- Define indexes and constraints
- Provide model-level methods (if any)

**Does NOT**:

- Contain business logic
- Handle validation (that's Pydantic's job)

```python
# src/models/product.py
from uuid import UUID
from sqlalchemy import String, Numeric, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from src.models.base import Base, TimestampMixin

class Product(Base, TimestampMixin):
    __tablename__ = "products"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(String(200))
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    created_by: Mapped[UUID] = mapped_column(ForeignKey("users.id"))

    # Relationships
    creator: Mapped["User"] = relationship(back_populates="products")
```

### Schemas Layer (`src/schemas/`)

**Purpose**: Data validation and serialization (Pydantic)

**Responsibilities**:

- Validate input data
- Define API response shapes
- Transform data between layers
- Document API contracts (OpenAPI)

**Does NOT**:

- Access database
- Contain business logic

```python
# src/schemas/product.py
from decimal import Decimal
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict

class ProductBase(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    price: Decimal = Field(gt=0, decimal_places=2)

class ProductCreate(ProductBase):
    pass

class ProductUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    price: Decimal | None = Field(default=None, gt=0)

class ProductResponse(ProductBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_by: UUID
    created_at: datetime
```

### Core Layer (`src/core/`)

**Purpose**: Application infrastructure and cross-cutting concerns

**Contents**:

| File | Purpose |
|------|---------|
| `config.py` | Environment-based settings via pydantic-settings |
| `database.py` | AsyncSession factory, engine setup |
| `security.py` | JWT encoding/decoding, password hashing |
| `exceptions.py` | Custom exception hierarchy |

### Utils Layer (`src/utils/`)

**Purpose**: Pure utility functions with no business logic

**Examples**:

- Logging setup
- Date/time helpers
- String formatting

## Comparison with .NET Clean Architecture

| .NET Layer | Python Equivalent | Notes |
|------------|-------------------|-------|
| `MyApp.Api` (Controllers) | `src/api/routes/` | FastAPI routers |
| `MyApp.Services` (Handlers) | `src/services/` | No CQRS split |
| `MyApp.Contracts` (DTOs) | `src/schemas/` | Pydantic models |
| `MyApp.Data` (Entities) | `src/models/` | SQLAlchemy models |
| `MyApp.Shared` | `src/core/`, `src/utils/` | Split by purpose |

## Import Conventions

Use absolute imports from the `src` package:

```python
# Good
from src.models.product import Product
from src.schemas.product import ProductCreate
from src.services.product_service import ProductService

# Avoid relative imports except within the same module
from .base import Base  # OK within models/
```

## File Naming

| Type | Convention | Example |
|------|------------|---------|
| Modules | `snake_case.py` | `product_service.py` |
| Test files | `test_<module>.py` | `test_product_service.py` |
| Migration files | Auto-generated by Alembic | `2024_01_15_add_products.py` |

See [Naming Conventions](../standards/naming-conventions.md) for complete guidelines.
