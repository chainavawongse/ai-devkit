# Router Patterns

## Overview

FastAPI routers are equivalent to .NET Controllers. They handle HTTP requests, validate input, call services, and return responses.

## Basic Router Structure

```python
# src/api/routes/products.py
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.api.dependencies import get_db, get_current_user, get_product_service
from src.models.user import User
from src.schemas.product import (
    ProductCreate,
    ProductUpdate,
    ProductResponse,
    ProductListResponse,
)
from src.services.product_service import ProductService

router = APIRouter(prefix="/products", tags=["products"])


@router.get("", response_model=ProductListResponse)
async def list_products(
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
    service: ProductService = Depends(get_product_service),
) -> ProductListResponse:
    """List all products with pagination."""
    products, total = await service.list(skip=skip, limit=limit)
    return ProductListResponse(items=products, total=total)


@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(
    product_id: UUID,
    service: ProductService = Depends(get_product_service),
) -> ProductResponse:
    """Get a single product by ID."""
    return await service.get_by_id(product_id)


@router.post("", status_code=status.HTTP_201_CREATED, response_model=ProductResponse)
async def create_product(
    data: ProductCreate,
    service: ProductService = Depends(get_product_service),
    current_user: User = Depends(get_current_user),
) -> ProductResponse:
    """Create a new product."""
    return await service.create(data, created_by=current_user.id)


@router.patch("/{product_id}", response_model=ProductResponse)
async def update_product(
    product_id: UUID,
    data: ProductUpdate,
    service: ProductService = Depends(get_product_service),
    current_user: User = Depends(get_current_user),
) -> ProductResponse:
    """Update an existing product."""
    return await service.update(product_id, data, updated_by=current_user.id)


@router.delete("/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_product(
    product_id: UUID,
    service: ProductService = Depends(get_product_service),
    current_user: User = Depends(get_current_user),
) -> None:
    """Delete a product."""
    await service.delete(product_id)
```

## Registering Routers

```python
# src/main.py
from fastapi import FastAPI
from src.api.routes import products, users, health

app = FastAPI(
    title="My API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Register routers
app.include_router(health.router)
app.include_router(products.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
```

## HTTP Methods

| Method | Use Case | Status Code |
|--------|----------|-------------|
| `GET` | Retrieve resource(s) | 200 OK |
| `POST` | Create resource | 201 Created |
| `PUT` | Full replacement | 200 OK |
| `PATCH` | Partial update | 200 OK |
| `DELETE` | Remove resource | 204 No Content |

## Path Parameters

```python
@router.get("/{product_id}")
async def get_product(product_id: UUID):  # Automatically validated as UUID
    ...

@router.get("/{product_id}/reviews/{review_id}")
async def get_review(product_id: UUID, review_id: UUID):
    ...
```

## Query Parameters

```python
from fastapi import Query
from enum import Enum

class SortOrder(str, Enum):
    asc = "asc"
    desc = "desc"

@router.get("")
async def list_products(
    # Required
    category: str,
    # Optional with default
    skip: int = Query(default=0, ge=0, description="Number of items to skip"),
    limit: int = Query(default=20, ge=1, le=100, description="Max items to return"),
    # Optional, nullable
    search: str | None = Query(default=None, min_length=1),
    # Enum validation
    sort: SortOrder = Query(default=SortOrder.desc),
    # List parameter (e.g., ?status=active&status=pending)
    status: list[str] = Query(default=[]),
):
    ...
```

## Request Body

```python
from pydantic import BaseModel, Field

class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    price: Decimal = Field(gt=0)
    description: str | None = None

@router.post("")
async def create_product(data: ProductCreate):  # Validated automatically
    ...

# Multiple body parameters (rare)
@router.post("/with-metadata")
async def create_with_metadata(
    product: ProductCreate,
    metadata: dict,
):
    ...
```

## Response Models

### Basic Response

```python
@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(product_id: UUID) -> ProductResponse:
    ...
```

### List Response with Pagination

```python
from pydantic import BaseModel

class PaginatedResponse[T](BaseModel):
    items: list[T]
    total: int
    skip: int
    limit: int

class ProductListResponse(PaginatedResponse[ProductResponse]):
    pass

@router.get("", response_model=ProductListResponse)
async def list_products(...) -> ProductListResponse:
    ...
```

### Different Response for Different Status Codes

```python
from fastapi import Response

@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    responses={
        201: {"model": ProductResponse, "description": "Product created"},
        409: {"description": "Product with this SKU already exists"},
    },
)
async def create_product(data: ProductCreate) -> ProductResponse:
    ...
```

## Headers and Cookies

```python
from fastapi import Header, Cookie

@router.get("")
async def get_products(
    x_correlation_id: str | None = Header(default=None, alias="X-Correlation-ID"),
    session_id: str | None = Cookie(default=None),
):
    ...

# Setting response headers
from fastapi import Response

@router.get("/{product_id}")
async def get_product(product_id: UUID, response: Response):
    response.headers["X-Custom-Header"] = "value"
    return product
```

## File Uploads

```python
from fastapi import File, UploadFile

@router.post("/{product_id}/image")
async def upload_image(
    product_id: UUID,
    file: UploadFile = File(...),
):
    contents = await file.read()
    # Process file...
    return {"filename": file.filename, "size": len(contents)}

# Multiple files
@router.post("/{product_id}/images")
async def upload_images(
    product_id: UUID,
    files: list[UploadFile] = File(...),
):
    ...
```

## Dependency Injection in Routes

```python
from fastapi import Depends
from src.api.dependencies import get_current_user, require_roles

# All routes require authentication
router = APIRouter(
    prefix="/admin/products",
    tags=["admin"],
    dependencies=[Depends(get_current_user)],  # Applied to all routes
)

# Specific route requires specific role
@router.delete("/{product_id}")
async def delete_product(
    product_id: UUID,
    current_user: User = Depends(require_roles("admin")),
):
    ...
```

## OpenAPI Documentation

```python
@router.post(
    "",
    summary="Create a new product",
    description="""
    Create a new product in the catalog.

    - **name**: Product display name
    - **price**: Price in USD (must be positive)
    - **sku**: Unique stock keeping unit
    """,
    response_description="The created product",
    responses={
        201: {"model": ProductResponse},
        409: {"description": "SKU already exists"},
        422: {"description": "Validation error"},
    },
    tags=["products"],
)
async def create_product(data: ProductCreate) -> ProductResponse:
    """
    Docstring also appears in OpenAPI.
    """
    ...
```

## Grouping Related Endpoints

```python
# src/api/routes/products/__init__.py
from fastapi import APIRouter
from . import crud, reviews, inventory

router = APIRouter(prefix="/products", tags=["products"])

router.include_router(crud.router)
router.include_router(reviews.router)
router.include_router(inventory.router)
```

```python
# src/api/routes/products/reviews.py
from fastapi import APIRouter

router = APIRouter()

@router.get("/{product_id}/reviews")
async def list_reviews(product_id: UUID):
    ...

@router.post("/{product_id}/reviews")
async def create_review(product_id: UUID, data: ReviewCreate):
    ...
```

## Background Tasks

```python
from fastapi import BackgroundTasks

async def send_notification(product_id: UUID):
    # Long-running task
    ...

@router.post("")
async def create_product(
    data: ProductCreate,
    background_tasks: BackgroundTasks,
) -> ProductResponse:
    product = await service.create(data)
    background_tasks.add_task(send_notification, product.id)
    return product
```

## Comparison with .NET Controllers

| .NET | FastAPI |
|------|---------|
| `[ApiController]` | `APIRouter()` |
| `[Route("api/[controller]")]` | `prefix="/products"` |
| `[HttpGet("{id}")]` | `@router.get("/{id}")` |
| `[FromBody]` | Parameter type (Pydantic model) |
| `[FromQuery]` | `Query()` |
| `[FromRoute]` | Path parameter |
| `[Authorize]` | `Depends(get_current_user)` |
| `IActionResult` | Return type or `Response` |
| `CreatedAtAction()` | `status_code=201` + return model |
| `NoContent()` | `status_code=204` + return `None` |

## Best Practices

### 1. Keep Routes Thin

```python
# Good - delegate to service
@router.post("")
async def create_product(
    data: ProductCreate,
    service: ProductService = Depends(get_product_service),
) -> ProductResponse:
    return await service.create(data)

# Avoid - business logic in route
@router.post("")
async def create_product(
    data: ProductCreate,
    db: AsyncSession = Depends(get_db),
) -> ProductResponse:
    # Don't put business logic here
    if await db.execute(select(Product).where(Product.sku == data.sku)).first():
        raise HTTPException(409, "SKU exists")
    product = Product(**data.model_dump())
    db.add(product)
    await db.commit()
    return product
```

### 2. Use Meaningful Status Codes

```python
# Good
@router.post("", status_code=status.HTTP_201_CREATED)
@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)

# Avoid - wrong status codes
@router.post("", status_code=200)  # Should be 201
@router.delete("/{id}")  # Returns 200 by default, should be 204
```

### 3. Validate at the Edge

```python
# Good - validation in Pydantic schema
class ProductCreate(BaseModel):
    price: Decimal = Field(gt=0)

# Avoid - validation in route
@router.post("")
async def create_product(data: ProductCreate):
    if data.price <= 0:  # Redundant
        raise HTTPException(400, "Price must be positive")
```

### 4. Consistent Naming

```python
# Good - RESTful naming
GET    /products           # list_products
GET    /products/{id}      # get_product
POST   /products           # create_product
PATCH  /products/{id}      # update_product
DELETE /products/{id}      # delete_product

# Avoid - verb-based URLs
POST /products/create
GET  /products/get/{id}
POST /products/delete/{id}
```
