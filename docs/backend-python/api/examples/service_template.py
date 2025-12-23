"""
Service Template - Business Logic Layer

This template demonstrates the standard patterns for service classes.
Services contain business logic and orchestrate database operations.
"""
from decimal import Decimal
from uuid import UUID

import structlog
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.core.exceptions import ConflictError, NotFoundError, ValidationError
from src.models.product import Product
from src.schemas.product import ProductCreate, ProductUpdate

logger = structlog.get_logger()


class ProductService:
    """Service for product operations."""

    def __init__(self, db: AsyncSession):
        """
        Initialize service with database session.

        Args:
            db: Async database session (injected via FastAPI Depends)
        """
        self.db = db

    # ============================================================
    # Read Operations
    # ============================================================

    async def get_by_id(self, product_id: UUID) -> Product:
        """
        Get a product by ID.

        Args:
            product_id: The product UUID

        Returns:
            The product entity

        Raises:
            NotFoundError: If product doesn't exist
        """
        result = await self.db.execute(
            select(Product).where(Product.id == product_id)
        )
        product = result.scalar_one_or_none()

        if not product:
            raise NotFoundError(
                message=f"Product {product_id} not found",
                details={"product_id": str(product_id)},
            )

        return product

    async def get_by_sku(self, sku: str) -> Product | None:
        """
        Get a product by SKU.

        Args:
            sku: The product SKU

        Returns:
            The product entity or None if not found
        """
        result = await self.db.execute(
            select(Product).where(Product.sku == sku)
        )
        return result.scalar_one_or_none()

    async def list(
        self,
        skip: int = 0,
        limit: int = 20,
        category_id: UUID | None = None,
        search: str | None = None,
    ) -> tuple[list[Product], int]:
        """
        List products with pagination and filters.

        Args:
            skip: Number of items to skip
            limit: Maximum items to return
            category_id: Optional category filter
            search: Optional search term

        Returns:
            Tuple of (products list, total count)
        """
        query = select(Product)

        # Apply filters
        if category_id:
            query = query.where(Product.category_id == category_id)
        if search:
            query = query.where(Product.name.ilike(f"%{search}%"))

        # Get total count
        count_query = select(func.count()).select_from(query.subquery())
        total = (await self.db.execute(count_query)).scalar_one()

        # Get paginated results
        query = (
            query
            .order_by(Product.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(query)
        products = list(result.scalars().all())

        return products, total

    async def get_with_relations(self, product_id: UUID) -> Product:
        """
        Get product with eager-loaded relations.

        Args:
            product_id: The product UUID

        Returns:
            Product with category and reviews loaded
        """
        result = await self.db.execute(
            select(Product)
            .where(Product.id == product_id)
            .options(
                selectinload(Product.category),
                selectinload(Product.reviews),
            )
        )
        product = result.scalar_one_or_none()

        if not product:
            raise NotFoundError(f"Product {product_id} not found")

        return product

    # ============================================================
    # Write Operations
    # ============================================================

    async def create(
        self,
        data: ProductCreate,
        created_by: UUID,
    ) -> Product:
        """
        Create a new product.

        Args:
            data: Product creation data
            created_by: ID of the user creating the product

        Returns:
            The created product

        Raises:
            ConflictError: If SKU already exists
            ValidationError: If business rules are violated
        """
        # Business validation
        if data.price < Decimal("0.01"):
            raise ValidationError(
                message="Price must be at least $0.01",
                code="InvalidPrice",
            )

        # Check for duplicate SKU
        existing = await self.get_by_sku(data.sku)
        if existing:
            raise ConflictError(
                message=f"Product with SKU {data.sku} already exists",
                code="DuplicateSKU",
                details={"sku": data.sku, "existing_id": str(existing.id)},
            )

        # Create product
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
        """
        Update an existing product.

        Args:
            product_id: The product UUID
            data: Fields to update (only non-None fields are applied)
            updated_by: ID of the user updating the product

        Returns:
            The updated product

        Raises:
            NotFoundError: If product doesn't exist
        """
        product = await self.get_by_id(product_id)

        # Apply only provided fields
        update_data = data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(product, field, value)

        product.updated_by = updated_by

        await self.db.commit()
        await self.db.refresh(product)

        logger.info(
            "product_updated",
            product_id=str(product_id),
            updated_fields=list(update_data.keys()),
            updated_by=str(updated_by),
        )

        return product

    async def delete(self, product_id: UUID) -> None:
        """
        Delete a product.

        Args:
            product_id: The product UUID

        Raises:
            NotFoundError: If product doesn't exist
        """
        product = await self.get_by_id(product_id)

        await self.db.delete(product)
        await self.db.commit()

        logger.info("product_deleted", product_id=str(product_id))

    # ============================================================
    # Business Operations
    # ============================================================

    async def publish(
        self,
        product_id: UUID,
        published_by: UUID,
    ) -> Product:
        """
        Publish a product (make visible to customers).

        Args:
            product_id: The product UUID
            published_by: ID of the user publishing

        Returns:
            The updated product

        Raises:
            NotFoundError: If product doesn't exist
            ValidationError: If product cannot be published
        """
        product = await self.get_by_id(product_id)

        # Business rule: must have price and description
        if not product.description:
            raise ValidationError(
                message="Product must have a description before publishing",
                code="MissingDescription",
            )

        product.is_published = True
        product.published_at = func.now()
        product.published_by = published_by

        await self.db.commit()
        await self.db.refresh(product)

        logger.info(
            "product_published",
            product_id=str(product_id),
            published_by=str(published_by),
        )

        return product

    async def bulk_update_prices(
        self,
        category_id: UUID,
        multiplier: Decimal,
    ) -> int:
        """
        Update all prices in a category by a multiplier.

        Args:
            category_id: Category to update
            multiplier: Price multiplier (e.g., 1.1 for 10% increase)

        Returns:
            Number of products updated
        """
        from sqlalchemy import update

        result = await self.db.execute(
            update(Product)
            .where(Product.category_id == category_id)
            .values(price=Product.price * multiplier)
        )
        await self.db.commit()

        count = result.rowcount
        logger.info(
            "bulk_prices_updated",
            category_id=str(category_id),
            multiplier=str(multiplier),
            count=count,
        )

        return count

    # ============================================================
    # Private Helpers
    # ============================================================

    async def _validate_category(self, category_id: UUID) -> None:
        """Verify category exists."""
        from src.models.category import Category

        result = await self.db.execute(
            select(Category.id).where(Category.id == category_id)
        )
        if not result.scalar_one_or_none():
            raise ValidationError(
                message=f"Category {category_id} not found",
                code="InvalidCategory",
            )
