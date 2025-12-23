# SQLAlchemy 2.0

## Overview

SQLAlchemy 2.0 with async support is the ORM layer, equivalent to Entity Framework Core in .NET. We use `asyncpg` as the PostgreSQL driver.

## Setup

### Engine and Session Factory

```python
# src/core/database.py
from collections.abc import AsyncGenerator
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from src.core.config import get_settings

settings = get_settings()

engine = create_async_engine(
    str(settings.database_url),
    echo=settings.debug,  # Log SQL in debug mode
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,  # Verify connections before use
)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,  # Keep objects usable after commit
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency that yields a database session."""
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

## Model Definition

### Base Model

```python
# src/models/base.py
from datetime import datetime
from uuid import UUID, uuid4
from sqlalchemy import DateTime, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    """Base class for all models."""
    pass


class TimestampMixin:
    """Mixin for created_at and updated_at timestamps."""

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        onupdate=func.now(),
        nullable=True,
    )


class UUIDPrimaryKeyMixin:
    """Mixin for UUID primary key."""

    id: Mapped[UUID] = mapped_column(
        primary_key=True,
        default=uuid4,
    )
```

### Entity Model

```python
# src/models/product.py
from decimal import Decimal
from uuid import UUID
from sqlalchemy import String, Numeric, ForeignKey, Text, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from src.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class Product(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "products"

    # Columns
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    sku: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    quantity: Mapped[int] = mapped_column(default=0, nullable=False)

    # Foreign keys
    category_id: Mapped[UUID] = mapped_column(
        ForeignKey("categories.id", ondelete="RESTRICT"),
        nullable=False,
    )
    created_by: Mapped[UUID] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
    )

    # Relationships
    category: Mapped["Category"] = relationship(back_populates="products")
    creator: Mapped["User"] = relationship(back_populates="created_products")
    reviews: Mapped[list["Review"]] = relationship(
        back_populates="product",
        cascade="all, delete-orphan",
    )

    # Indexes
    __table_args__ = (
        Index("ix_products_category_id", "category_id"),
        Index("ix_products_created_at", "created_at"),
    )

    def __repr__(self) -> str:
        return f"<Product {self.sku}: {self.name}>"
```

### Relationships

```python
# One-to-Many
class Category(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "categories"

    name: Mapped[str] = mapped_column(String(100))

    # One category has many products
    products: Mapped[list["Product"]] = relationship(
        back_populates="category",
        lazy="selectin",  # Eager load by default
    )


# Many-to-Many
product_tags = Table(
    "product_tags",
    Base.metadata,
    Column("product_id", ForeignKey("products.id"), primary_key=True),
    Column("tag_id", ForeignKey("tags.id"), primary_key=True),
)


class Product(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "products"

    tags: Mapped[list["Tag"]] = relationship(
        secondary=product_tags,
        back_populates="products",
    )


class Tag(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "tags"

    name: Mapped[str] = mapped_column(String(50), unique=True)
    products: Mapped[list["Product"]] = relationship(
        secondary=product_tags,
        back_populates="tags",
    )
```

## Querying

### Basic Queries

```python
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession


async def get_product_by_id(db: AsyncSession, product_id: UUID) -> Product | None:
    """Get a single product by ID."""
    result = await db.execute(
        select(Product).where(Product.id == product_id)
    )
    return result.scalar_one_or_none()


async def get_products_by_category(
    db: AsyncSession,
    category_id: UUID,
) -> list[Product]:
    """Get all products in a category."""
    result = await db.execute(
        select(Product)
        .where(Product.category_id == category_id)
        .order_by(Product.name)
    )
    return list(result.scalars().all())
```

### Filtering

```python
from sqlalchemy import select, and_, or_


async def search_products(
    db: AsyncSession,
    search: str | None = None,
    category_id: UUID | None = None,
    min_price: Decimal | None = None,
    max_price: Decimal | None = None,
) -> list[Product]:
    """Search products with multiple filters."""
    query = select(Product)

    conditions = []
    if search:
        conditions.append(
            or_(
                Product.name.ilike(f"%{search}%"),
                Product.description.ilike(f"%{search}%"),
            )
        )
    if category_id:
        conditions.append(Product.category_id == category_id)
    if min_price is not None:
        conditions.append(Product.price >= min_price)
    if max_price is not None:
        conditions.append(Product.price <= max_price)

    if conditions:
        query = query.where(and_(*conditions))

    result = await db.execute(query.order_by(Product.created_at.desc()))
    return list(result.scalars().all())
```

### Pagination

```python
from sqlalchemy import select, func


async def get_products_paginated(
    db: AsyncSession,
    skip: int = 0,
    limit: int = 20,
) -> tuple[list[Product], int]:
    """Get paginated products with total count."""
    # Total count
    count_result = await db.execute(select(func.count(Product.id)))
    total = count_result.scalar_one()

    # Paginated results
    result = await db.execute(
        select(Product)
        .order_by(Product.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    products = list(result.scalars().all())

    return products, total
```

### Eager Loading

```python
from sqlalchemy.orm import selectinload, joinedload


async def get_product_with_reviews(
    db: AsyncSession,
    product_id: UUID,
) -> Product | None:
    """Get product with reviews eagerly loaded."""
    result = await db.execute(
        select(Product)
        .where(Product.id == product_id)
        .options(selectinload(Product.reviews))  # One-to-many: selectinload
    )
    return result.scalar_one_or_none()


async def get_product_with_category(
    db: AsyncSession,
    product_id: UUID,
) -> Product | None:
    """Get product with category eagerly loaded."""
    result = await db.execute(
        select(Product)
        .where(Product.id == product_id)
        .options(joinedload(Product.category))  # Many-to-one: joinedload
    )
    return result.scalar_one_or_none()


async def get_products_with_all_relations(db: AsyncSession) -> list[Product]:
    """Get products with multiple relations."""
    result = await db.execute(
        select(Product)
        .options(
            joinedload(Product.category),
            selectinload(Product.reviews),
            selectinload(Product.tags),
        )
    )
    return list(result.scalars().unique().all())  # unique() for joinedload
```

### Aggregations

```python
from sqlalchemy import select, func


async def get_category_stats(db: AsyncSession) -> list[dict]:
    """Get product count and average price per category."""
    result = await db.execute(
        select(
            Category.name,
            func.count(Product.id).label("product_count"),
            func.avg(Product.price).label("avg_price"),
        )
        .join(Product, Category.id == Product.category_id)
        .group_by(Category.id)
        .order_by(func.count(Product.id).desc())
    )
    return [
        {"name": row.name, "count": row.product_count, "avg_price": row.avg_price}
        for row in result.all()
    ]
```

## CRUD Operations

### Create

```python
async def create_product(
    db: AsyncSession,
    data: ProductCreate,
    created_by: UUID,
) -> Product:
    """Create a new product."""
    product = Product(
        **data.model_dump(),
        created_by=created_by,
    )
    db.add(product)
    await db.commit()
    await db.refresh(product)
    return product
```

### Update

```python
async def update_product(
    db: AsyncSession,
    product_id: UUID,
    data: ProductUpdate,
) -> Product:
    """Update an existing product."""
    result = await db.execute(
        select(Product).where(Product.id == product_id)
    )
    product = result.scalar_one_or_none()
    if not product:
        raise NotFoundError(f"Product {product_id} not found")

    # Apply only provided fields
    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(product, field, value)

    await db.commit()
    await db.refresh(product)
    return product
```

### Delete

```python
async def delete_product(db: AsyncSession, product_id: UUID) -> None:
    """Delete a product."""
    result = await db.execute(
        select(Product).where(Product.id == product_id)
    )
    product = result.scalar_one_or_none()
    if not product:
        raise NotFoundError(f"Product {product_id} not found")

    await db.delete(product)
    await db.commit()
```

### Bulk Operations

```python
from sqlalchemy import update, delete


async def bulk_update_prices(
    db: AsyncSession,
    category_id: UUID,
    multiplier: Decimal,
) -> int:
    """Update all prices in a category."""
    result = await db.execute(
        update(Product)
        .where(Product.category_id == category_id)
        .values(price=Product.price * multiplier)
    )
    await db.commit()
    return result.rowcount


async def bulk_delete_old_products(
    db: AsyncSession,
    older_than: datetime,
) -> int:
    """Delete products older than a date."""
    result = await db.execute(
        delete(Product).where(Product.created_at < older_than)
    )
    await db.commit()
    return result.rowcount
```

## Transactions

### Implicit Transaction

The session dependency handles transactions automatically:

```python
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()  # Auto-commit on success
        except Exception:
            await session.rollback()  # Auto-rollback on error
            raise
```

### Explicit Transaction

```python
async def transfer_inventory(
    db: AsyncSession,
    from_id: UUID,
    to_id: UUID,
    quantity: int,
) -> None:
    """Transfer inventory atomically."""
    async with db.begin():  # Explicit transaction
        from_product = await db.get(Product, from_id)
        to_product = await db.get(Product, to_id)

        if from_product.quantity < quantity:
            raise ValidationError("Insufficient inventory")

        from_product.quantity -= quantity
        to_product.quantity += quantity
        # Auto-commit at end of `async with`
```

### Nested Operations with Flush

```python
async def create_order_with_items(
    db: AsyncSession,
    order_data: OrderCreate,
    items_data: list[OrderItemCreate],
) -> Order:
    """Create order and items together."""
    order = Order(**order_data.model_dump())
    db.add(order)
    await db.flush()  # Get order.id without committing

    for item_data in items_data:
        item = OrderItem(**item_data.model_dump(), order_id=order.id)
        db.add(item)

    await db.commit()
    await db.refresh(order)
    return order
```

## Raw SQL

```python
from sqlalchemy import text


async def execute_raw_query(db: AsyncSession, category: str) -> list[dict]:
    """Execute raw SQL when needed."""
    result = await db.execute(
        text("""
            SELECT p.id, p.name, c.name as category_name
            FROM products p
            JOIN categories c ON p.category_id = c.id
            WHERE c.name = :category
            ORDER BY p.created_at DESC
        """),
        {"category": category},
    )
    return [dict(row._mapping) for row in result.all()]
```

## Comparison with Entity Framework Core

| EF Core | SQLAlchemy |
|---------|------------|
| `DbContext` | `AsyncSession` |
| `DbSet<T>` | `select(Model)` |
| `Include()` | `options(selectinload())` |
| `ThenInclude()` | Chained `selectinload()` |
| `AsNoTracking()` | Not needed (expire_on_commit=False) |
| `FirstOrDefaultAsync()` | `scalar_one_or_none()` |
| `ToListAsync()` | `scalars().all()` |
| LINQ `Where()` | `.where()` |
| `SaveChangesAsync()` | `commit()` |
| `Add()` | `add()` |
| `Entry().State = Modified` | Direct attribute assignment |

## Best Practices

### 1. Use `select()` Not Legacy Query

```python
# Good - SQLAlchemy 2.0 style
result = await db.execute(select(Product).where(Product.id == id))
product = result.scalar_one_or_none()

# Avoid - legacy 1.x style
product = await db.query(Product).filter(Product.id == id).first()
```

### 2. Use Type Hints

```python
# Good
class Product(Base):
    name: Mapped[str] = mapped_column(String(200))
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2))

# Avoid - old style
class Product(Base):
    name = Column(String(200))  # No type hints
```

### 3. Eager Load Relationships

```python
# Good - explicit loading
result = await db.execute(
    select(Product).options(selectinload(Product.reviews))
)

# Avoid - lazy loading (causes N+1 queries)
products = result.scalars().all()
for p in products:
    print(p.reviews)  # Each access triggers a query!
```

### 4. Use Indexes

```python
class Product(Base):
    __tablename__ = "products"

    __table_args__ = (
        Index("ix_products_category_created", "category_id", "created_at"),
        Index("ix_products_sku", "sku", unique=True),
    )
```

### 5. Handle None Checks

```python
# Good - explicit None handling
product = result.scalar_one_or_none()
if not product:
    raise NotFoundError(f"Product {id} not found")

# Avoid - assuming result exists
product = result.scalar_one()  # Raises if not found or multiple
```
