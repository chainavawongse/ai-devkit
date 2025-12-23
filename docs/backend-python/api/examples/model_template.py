"""
Model Template - SQLAlchemy ORM Models

This template demonstrates the standard patterns for SQLAlchemy models.
Models define database schema and relationships.
"""
from datetime import datetime
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.models.base import Base


# ============================================================
# Base Mixins (Reusable Components)
# ============================================================
class UUIDPrimaryKeyMixin:
    """Mixin for UUID primary key."""

    id: Mapped[UUID] = mapped_column(
        primary_key=True,
        default=uuid4,
    )


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


class AuditMixin:
    """Mixin for audit fields (who created/updated)."""

    created_by: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id"),
        nullable=True,
    )
    updated_by: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id"),
        nullable=True,
    )


# ============================================================
# Main Entity Model
# ============================================================
class Product(Base, UUIDPrimaryKeyMixin, TimestampMixin, AuditMixin):
    """
    Product entity.

    Represents a product in the catalog with pricing,
    categorization, and publication status.
    """

    __tablename__ = "products"

    # --------------------------------------------------------
    # Basic Fields
    # --------------------------------------------------------
    name: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
        comment="Product display name",
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Product description (supports markdown)",
    )

    sku: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        nullable=False,
        index=True,
        comment="Stock keeping unit (unique identifier)",
    )

    price: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
        comment="Price in USD",
    )

    quantity: Mapped[int] = mapped_column(
        default=0,
        nullable=False,
        comment="Available inventory quantity",
    )

    # --------------------------------------------------------
    # Status Fields
    # --------------------------------------------------------
    is_active: Mapped[bool] = mapped_column(
        default=True,
        nullable=False,
        comment="Whether product is active in the system",
    )

    is_published: Mapped[bool] = mapped_column(
        default=False,
        nullable=False,
        comment="Whether product is visible to customers",
    )

    published_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="When the product was published",
    )

    # --------------------------------------------------------
    # Foreign Keys
    # --------------------------------------------------------
    category_id: Mapped[UUID] = mapped_column(
        ForeignKey("categories.id", ondelete="RESTRICT"),
        nullable=False,
        comment="Product category",
    )

    # --------------------------------------------------------
    # Relationships
    # --------------------------------------------------------

    # Many-to-One: Product belongs to one Category
    category: Mapped["Category"] = relationship(
        back_populates="products",
        lazy="raise",  # Prevent lazy loading; force explicit load
    )

    # One-to-Many: Product has many Reviews
    reviews: Mapped[list["Review"]] = relationship(
        back_populates="product",
        cascade="all, delete-orphan",  # Delete reviews when product deleted
        lazy="raise",
    )

    # Many-to-Many: Product has many Tags
    tags: Mapped[list["Tag"]] = relationship(
        secondary="product_tags",
        back_populates="products",
        lazy="raise",
    )

    # Self-referential: Related products
    related_products: Mapped[list["Product"]] = relationship(
        secondary="related_products",
        primaryjoin="Product.id == related_products.c.product_id",
        secondaryjoin="Product.id == related_products.c.related_id",
        lazy="raise",
    )

    # Audit relationships (optional)
    creator: Mapped["User"] = relationship(
        foreign_keys="[Product.created_by]",
        lazy="raise",
    )

    # --------------------------------------------------------
    # Table Configuration
    # --------------------------------------------------------
    __table_args__ = (
        # Indexes
        Index("ix_products_category_id", "category_id"),
        Index("ix_products_created_at", "created_at"),
        Index("ix_products_is_published", "is_published"),

        # Composite index for common queries
        Index(
            "ix_products_category_published",
            "category_id",
            "is_published",
            "created_at",
        ),

        # Check constraints
        CheckConstraint("price > 0", name="ck_products_positive_price"),
        CheckConstraint("quantity >= 0", name="ck_products_non_negative_quantity"),

        # Table comment
        {"comment": "Products in the catalog"},
    )

    # --------------------------------------------------------
    # Methods
    # --------------------------------------------------------
    def __repr__(self) -> str:
        return f"<Product {self.sku}: {self.name}>"

    @property
    def is_in_stock(self) -> bool:
        """Check if product is in stock."""
        return self.quantity > 0

    @property
    def is_visible(self) -> bool:
        """Check if product is visible to customers."""
        return self.is_active and self.is_published


# ============================================================
# Related Entity (Category)
# ============================================================
class Category(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """Product category."""

    __tablename__ = "categories"

    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    slug: Mapped[str] = mapped_column(
        String(100),
        unique=True,
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    # Self-referential: Parent category
    parent_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("categories.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Relationships
    products: Mapped[list["Product"]] = relationship(
        back_populates="category",
        lazy="raise",
    )

    parent: Mapped["Category | None"] = relationship(
        remote_side="Category.id",
        lazy="raise",
    )

    children: Mapped[list["Category"]] = relationship(
        back_populates="parent",
        lazy="raise",
    )


# ============================================================
# Junction Table (Many-to-Many)
# ============================================================
from sqlalchemy import Column, Table

# Simple junction table (no extra fields)
product_tags = Table(
    "product_tags",
    Base.metadata,
    Column("product_id", ForeignKey("products.id", ondelete="CASCADE"), primary_key=True),
    Column("tag_id", ForeignKey("tags.id", ondelete="CASCADE"), primary_key=True),
)


class Tag(Base, UUIDPrimaryKeyMixin):
    """Product tag for classification."""

    __tablename__ = "tags"

    name: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        nullable=False,
    )

    products: Mapped[list["Product"]] = relationship(
        secondary=product_tags,
        back_populates="tags",
        lazy="raise",
    )


# Self-referential many-to-many
related_products = Table(
    "related_products",
    Base.metadata,
    Column("product_id", ForeignKey("products.id", ondelete="CASCADE"), primary_key=True),
    Column("related_id", ForeignKey("products.id", ondelete="CASCADE"), primary_key=True),
)


# ============================================================
# Junction Table with Extra Fields (Association Object)
# ============================================================
class OrderItem(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """
    Order line item - junction table with extra fields.

    Use an association object when the relationship
    needs to carry additional data.
    """

    __tablename__ = "order_items"

    # Foreign keys
    order_id: Mapped[UUID] = mapped_column(
        ForeignKey("orders.id", ondelete="CASCADE"),
        nullable=False,
    )
    product_id: Mapped[UUID] = mapped_column(
        ForeignKey("products.id", ondelete="RESTRICT"),
        nullable=False,
    )

    # Extra fields on the relationship
    quantity: Mapped[int] = mapped_column(
        nullable=False,
    )
    unit_price: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
        comment="Price at time of order (may differ from current product price)",
    )

    # Relationships
    order: Mapped["Order"] = relationship(back_populates="items")
    product: Mapped["Product"] = relationship()

    __table_args__ = (
        UniqueConstraint("order_id", "product_id", name="uq_order_items_order_product"),
        CheckConstraint("quantity > 0", name="ck_order_items_positive_quantity"),
    )

    @property
    def subtotal(self) -> Decimal:
        """Calculate line item subtotal."""
        return self.quantity * self.unit_price


# ============================================================
# Enum Fields
# ============================================================
from enum import Enum as PyEnum


class OrderStatus(str, PyEnum):
    """Order status values."""

    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"


class Order(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """Customer order."""

    __tablename__ = "orders"

    # Enum column
    status: Mapped[OrderStatus] = mapped_column(
        default=OrderStatus.PENDING,
        nullable=False,
    )

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
    )

    items: Mapped[list["OrderItem"]] = relationship(
        back_populates="order",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        Index("ix_orders_user_id_status", "user_id", "status"),
    )
