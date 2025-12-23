"""
Schema Template - Pydantic Models for Validation and Serialization

This template demonstrates the standard patterns for Pydantic schemas.
Schemas handle API request/response validation and serialization.
"""
from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, computed_field, field_validator


# ============================================================
# Base Schema (Shared Fields)
# ============================================================
class ProductBase(BaseModel):
    """
    Base schema with fields shared across create/update/response.

    Use inheritance to avoid duplication while maintaining flexibility.
    """

    name: str = Field(
        min_length=1,
        max_length=200,
        description="Product display name",
        examples=["Premium Widget"],
    )
    description: str | None = Field(
        default=None,
        max_length=2000,
        description="Product description",
    )
    price: Decimal = Field(
        gt=0,
        decimal_places=2,
        description="Price in USD",
        examples=["29.99"],
    )


# ============================================================
# Create Schema (POST Request Body)
# ============================================================
class ProductCreate(ProductBase):
    """
    Schema for creating a new product.

    Includes all required fields for creation.
    """

    sku: str = Field(
        pattern=r"^[A-Z0-9-]+$",
        max_length=50,
        description="Stock keeping unit (uppercase alphanumeric with dashes)",
        examples=["WIDGET-001"],
    )
    category_id: UUID = Field(
        description="Category UUID",
    )

    @field_validator("sku")
    @classmethod
    def uppercase_sku(cls, v: str) -> str:
        """Normalize SKU to uppercase."""
        return v.upper()


# ============================================================
# Update Schema (PATCH Request Body)
# ============================================================
class ProductUpdate(BaseModel):
    """
    Schema for updating a product.

    All fields are optional - only provided fields are updated.
    """

    name: str | None = Field(
        default=None,
        min_length=1,
        max_length=200,
    )
    description: str | None = None
    price: Decimal | None = Field(
        default=None,
        gt=0,
        decimal_places=2,
    )
    category_id: UUID | None = None


# ============================================================
# Response Schema (API Response)
# ============================================================
class ProductResponse(ProductBase):
    """
    Schema for product API responses.

    Uses `from_attributes=True` to convert from SQLAlchemy models.
    """

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    sku: str
    category_id: UUID
    is_published: bool = False
    created_at: datetime
    updated_at: datetime | None = None
    created_by: UUID


# ============================================================
# Response with Computed Fields
# ============================================================
class ProductDetailResponse(ProductResponse):
    """
    Extended product response with computed fields.
    """

    category_name: str | None = None  # From joined relation
    review_count: int = 0

    @computed_field
    @property
    def formatted_price(self) -> str:
        """Format price as currency string."""
        return f"${self.price:.2f}"


# ============================================================
# List Response (Paginated)
# ============================================================
class ProductListResponse(BaseModel):
    """
    Paginated list response for products.
    """

    items: list[ProductResponse]
    total: int = Field(description="Total number of items (ignoring pagination)")
    skip: int = Field(description="Number of items skipped")
    limit: int = Field(description="Maximum items per page")

    @computed_field
    @property
    def has_more(self) -> bool:
        """Check if there are more items beyond this page."""
        return self.skip + len(self.items) < self.total


# ============================================================
# Nested Schemas
# ============================================================
class CategoryInfo(BaseModel):
    """Minimal category info for embedding."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str


class ProductWithCategoryResponse(ProductResponse):
    """Product response with nested category."""

    category: CategoryInfo | None = None


# ============================================================
# Query Parameters Schema
# ============================================================
class ProductQueryParams(BaseModel):
    """
    Schema for query parameters (optional, for complex validation).

    Usually query params are defined inline with `Query()`,
    but this pattern is useful for complex validation.
    """

    skip: int = Field(default=0, ge=0)
    limit: int = Field(default=20, ge=1, le=100)
    category_id: UUID | None = None
    min_price: Decimal | None = Field(default=None, ge=0)
    max_price: Decimal | None = Field(default=None, ge=0)
    search: str | None = Field(default=None, min_length=1)

    @field_validator("max_price")
    @classmethod
    def max_price_greater_than_min(
        cls, v: Decimal | None, info
    ) -> Decimal | None:
        """Validate max_price is greater than min_price."""
        min_price = info.data.get("min_price")
        if v is not None and min_price is not None and v < min_price:
            raise ValueError("max_price must be greater than min_price")
        return v


# ============================================================
# Enum-Based Schema
# ============================================================
from enum import Enum


class ProductStatus(str, Enum):
    """Product status enum."""

    DRAFT = "draft"
    PUBLISHED = "published"
    ARCHIVED = "archived"


class ProductStatusUpdate(BaseModel):
    """Schema for updating product status."""

    status: ProductStatus


# ============================================================
# Error Response Schema
# ============================================================
class ErrorDetail(BaseModel):
    """Standard error detail."""

    code: str = Field(description="Error code for programmatic handling")
    message: str = Field(description="Human-readable error message")
    details: dict | None = Field(default=None, description="Additional error details")


class ErrorResponse(BaseModel):
    """Standard error response wrapper."""

    error: ErrorDetail


# ============================================================
# Common Patterns
# ============================================================
class IdResponse(BaseModel):
    """Simple ID response for create operations."""

    id: UUID


class SuccessResponse(BaseModel):
    """Simple success response."""

    success: bool = True
    message: str | None = None


class BulkOperationResponse(BaseModel):
    """Response for bulk operations."""

    affected_count: int
    success: bool = True
