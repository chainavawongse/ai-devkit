# Service Patterns

## Overview

Services contain business logic and orchestrate database operations. Unlike .NET's CQRS pattern with separate command/query handlers, Python services typically combine both in a single class.

## Basic Service Structure

```python
# src/services/product_service.py
from uuid import UUID
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
import structlog

from src.models.product import Product
from src.schemas.product import ProductCreate, ProductUpdate, ProductResponse
from src.core.exceptions import NotFoundError, ConflictError

logger = structlog.get_logger()


class ProductService:
    """Service for product operations."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, product_id: UUID) -> Product:
        """Get a product by ID or raise NotFoundError."""
        result = await self.db.execute(
            select(Product).where(Product.id == product_id)
        )
        product = result.scalar_one_or_none()

        if not product:
            raise NotFoundError(f"Product {product_id} not found")

        return product

    async def list(
        self,
        skip: int = 0,
        limit: int = 20,
    ) -> tuple[list[Product], int]:
        """List products with pagination."""
        # Get total count
        count_result = await self.db.execute(select(func.count(Product.id)))
        total = count_result.scalar_one()

        # Get paginated results
        result = await self.db.execute(
            select(Product)
            .order_by(Product.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        products = list(result.scalars().all())

        return products, total

    async def create(
        self,
        data: ProductCreate,
        created_by: UUID,
    ) -> Product:
        """Create a new product."""
        # Check for duplicate SKU
        existing = await self.db.execute(
            select(Product).where(Product.sku == data.sku)
        )
        if existing.scalar_one_or_none():
            raise ConflictError(f"Product with SKU {data.sku} already exists")

        product = Product(
            **data.model_dump(),
            created_by=created_by,
        )
        self.db.add(product)
        await self.db.commit()
        await self.db.refresh(product)

        logger.info(
            "product_created",
            product_id=str(product.id),
            sku=product.sku,
            created_by=str(created_by),
        )

        return product

    async def update(
        self,
        product_id: UUID,
        data: ProductUpdate,
        updated_by: UUID,
    ) -> Product:
        """Update an existing product."""
        product = await self.get_by_id(product_id)

        # Apply updates (only non-None values)
        update_data = data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(product, field, value)

        product.updated_by = updated_by
        await self.db.commit()
        await self.db.refresh(product)

        logger.info(
            "product_updated",
            product_id=str(product_id),
            fields=list(update_data.keys()),
        )

        return product

    async def delete(self, product_id: UUID) -> None:
        """Delete a product."""
        product = await self.get_by_id(product_id)
        await self.db.delete(product)
        await self.db.commit()

        logger.info("product_deleted", product_id=str(product_id))
```

## Service with External Dependencies

```python
# src/services/order_service.py
from uuid import UUID
import httpx
from sqlalchemy.ext.asyncio import AsyncSession
import structlog

from src.models.order import Order
from src.schemas.order import OrderCreate
from src.core.config import Settings
from src.core.exceptions import ServiceUnavailableError

logger = structlog.get_logger()


class OrderService:
    """Service for order operations with external integrations."""

    def __init__(
        self,
        db: AsyncSession,
        http_client: httpx.AsyncClient,
        settings: Settings,
    ):
        self.db = db
        self.http_client = http_client
        self.settings = settings

    async def create(self, data: OrderCreate, user_id: UUID) -> Order:
        """Create order and notify external system."""
        order = Order(**data.model_dump(), user_id=user_id)
        self.db.add(order)
        await self.db.commit()
        await self.db.refresh(order)

        # Notify external service
        await self._notify_fulfillment(order)

        return order

    async def _notify_fulfillment(self, order: Order) -> None:
        """Notify fulfillment service about new order."""
        try:
            response = await self.http_client.post(
                f"{self.settings.fulfillment_api_url}/orders",
                json={"order_id": str(order.id), "items": order.items},
                timeout=10.0,
            )
            response.raise_for_status()
        except httpx.HTTPError as e:
            logger.error(
                "fulfillment_notification_failed",
                order_id=str(order.id),
                error=str(e),
            )
            # Decide: raise or handle gracefully
            # raise ServiceUnavailableError("Fulfillment service unavailable")
```

## Dependency Injection Setup

```python
# src/api/dependencies.py
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
import httpx

from src.core.database import get_db
from src.core.config import Settings, get_settings
from src.services.product_service import ProductService
from src.services.order_service import OrderService


# Simple service (DB only)
def get_product_service(
    db: AsyncSession = Depends(get_db),
) -> ProductService:
    return ProductService(db)


# Service with multiple dependencies
_http_client: httpx.AsyncClient | None = None

async def get_http_client() -> httpx.AsyncClient:
    global _http_client
    if _http_client is None:
        _http_client = httpx.AsyncClient()
    return _http_client


def get_order_service(
    db: AsyncSession = Depends(get_db),
    http_client: httpx.AsyncClient = Depends(get_http_client),
    settings: Settings = Depends(get_settings),
) -> OrderService:
    return OrderService(db, http_client, settings)
```

## Query Patterns

### Filtering

```python
async def list(
    self,
    category: str | None = None,
    min_price: Decimal | None = None,
    max_price: Decimal | None = None,
    search: str | None = None,
    skip: int = 0,
    limit: int = 20,
) -> tuple[list[Product], int]:
    """List products with optional filters."""
    query = select(Product)

    # Build filters dynamically
    if category:
        query = query.where(Product.category == category)
    if min_price is not None:
        query = query.where(Product.price >= min_price)
    if max_price is not None:
        query = query.where(Product.price <= max_price)
    if search:
        query = query.where(Product.name.ilike(f"%{search}%"))

    # Count total
    count_query = select(func.count()).select_from(query.subquery())
    total = (await self.db.execute(count_query)).scalar_one()

    # Paginate
    query = query.order_by(Product.created_at.desc()).offset(skip).limit(limit)
    result = await self.db.execute(query)

    return list(result.scalars().all()), total
```

### Eager Loading Relationships

```python
from sqlalchemy.orm import selectinload, joinedload

async def get_with_reviews(self, product_id: UUID) -> Product:
    """Get product with reviews eagerly loaded."""
    result = await self.db.execute(
        select(Product)
        .where(Product.id == product_id)
        .options(selectinload(Product.reviews))  # One-to-many
    )
    product = result.scalar_one_or_none()
    if not product:
        raise NotFoundError(f"Product {product_id} not found")
    return product


async def get_with_category(self, product_id: UUID) -> Product:
    """Get product with category eagerly loaded."""
    result = await self.db.execute(
        select(Product)
        .where(Product.id == product_id)
        .options(joinedload(Product.category))  # Many-to-one
    )
    return result.scalar_one_or_none()
```

### Bulk Operations

```python
from sqlalchemy import update, delete

async def bulk_update_prices(
    self,
    category: str,
    multiplier: Decimal,
) -> int:
    """Update all prices in a category."""
    result = await self.db.execute(
        update(Product)
        .where(Product.category == category)
        .values(price=Product.price * multiplier)
    )
    await self.db.commit()
    return result.rowcount


async def bulk_delete_old(self, days: int) -> int:
    """Delete products older than N days."""
    cutoff = datetime.utcnow() - timedelta(days=days)
    result = await self.db.execute(
        delete(Product).where(Product.created_at < cutoff)
    )
    await self.db.commit()
    return result.rowcount
```

## Transaction Patterns

### Implicit Transaction (Default)

The database session handles transactions automatically via the dependency:

```python
# src/core/database.py
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()  # Commit on success
        except Exception:
            await session.rollback()  # Rollback on error
            raise
```

### Explicit Transaction Control

```python
async def transfer_inventory(
    self,
    from_product_id: UUID,
    to_product_id: UUID,
    quantity: int,
) -> None:
    """Transfer inventory between products atomically."""
    async with self.db.begin():  # Explicit transaction
        from_product = await self.get_by_id(from_product_id)
        to_product = await self.get_by_id(to_product_id)

        if from_product.quantity < quantity:
            raise ValidationError("Insufficient inventory")

        from_product.quantity -= quantity
        to_product.quantity += quantity
        # Commit happens automatically at end of `async with`
```

### Nested Operations

```python
async def create_order_with_items(
    self,
    order_data: OrderCreate,
    items: list[OrderItemCreate],
) -> Order:
    """Create order and items in single transaction."""
    order = Order(**order_data.model_dump())
    self.db.add(order)
    await self.db.flush()  # Get order.id without committing

    for item_data in items:
        item = OrderItem(**item_data.model_dump(), order_id=order.id)
        self.db.add(item)

    await self.db.commit()
    await self.db.refresh(order)
    return order
```

## Error Handling in Services

```python
from src.core.exceptions import NotFoundError, ConflictError, ValidationError

class ProductService:
    async def create(self, data: ProductCreate) -> Product:
        # Business validation
        if data.price < data.cost:
            raise ValidationError("Price cannot be less than cost")

        # Uniqueness check
        existing = await self._get_by_sku(data.sku)
        if existing:
            raise ConflictError(f"SKU {data.sku} already exists")

        # Create product
        product = Product(**data.model_dump())
        self.db.add(product)
        await self.db.commit()
        return product

    async def get_by_id(self, product_id: UUID) -> Product:
        product = await self._fetch_by_id(product_id)
        if not product:
            raise NotFoundError(f"Product {product_id} not found")
        return product
```

## Testing Services

```python
# tests/unit/services/test_product_service.py
import pytest
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

from src.services.product_service import ProductService
from src.schemas.product import ProductCreate
from src.core.exceptions import NotFoundError


@pytest.fixture
def mock_db():
    return AsyncMock()


@pytest.fixture
def service(mock_db):
    return ProductService(mock_db)


async def test_get_by_id_found(service, mock_db):
    product_id = uuid4()
    mock_product = MagicMock(id=product_id, name="Test")

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_product
    mock_db.execute.return_value = mock_result

    result = await service.get_by_id(product_id)

    assert result.id == product_id


async def test_get_by_id_not_found(service, mock_db):
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result

    with pytest.raises(NotFoundError):
        await service.get_by_id(uuid4())
```

## Comparison with .NET Patterns

| .NET Pattern | Python Equivalent |
|--------------|-------------------|
| `IRequestHandler<TRequest, TResponse>` | Service method |
| Command/Query separation | Combined in service class |
| `IRepository<T>` | Direct SQLAlchemy in service |
| AutoMapper | `model_dump()` / manual mapping |
| FluentValidation | Pydantic + service validation |
| `IUnitOfWork` | `AsyncSession` (implicit UoW) |

## Best Practices

### 1. Single Responsibility

```python
# Good - focused service
class ProductService:
    async def create(self, data: ProductCreate) -> Product: ...
    async def update(self, id: UUID, data: ProductUpdate) -> Product: ...

class ProductSearchService:
    async def search(self, query: str) -> list[Product]: ...
    async def suggest(self, prefix: str) -> list[str]: ...

# Avoid - god service
class ProductService:
    async def create(...): ...
    async def search(...): ...
    async def send_notification(...): ...
    async def generate_report(...): ...
```

### 2. Raise Domain Exceptions

```python
# Good - domain exceptions
raise NotFoundError(f"Product {product_id} not found")
raise ConflictError(f"SKU {sku} already exists")

# Avoid - HTTP exceptions in service
raise HTTPException(status_code=404, detail="Not found")  # Couples to HTTP
```

### 3. Log with Context

```python
# Good - structured logging
logger.info(
    "product_created",
    product_id=str(product.id),
    sku=product.sku,
    price=str(product.price),
)

# Avoid - string formatting
logger.info(f"Created product {product.id}")
```

### 4. Keep Services Stateless

```python
# Good - stateless, receives DB via __init__
class ProductService:
    def __init__(self, db: AsyncSession):
        self.db = db

# Avoid - storing state between calls
class ProductService:
    def __init__(self):
        self.last_created_product = None  # Bad!
```
