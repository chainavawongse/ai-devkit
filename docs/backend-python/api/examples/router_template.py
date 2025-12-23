"""
Router Template - FastAPI Router with CRUD Operations

This template demonstrates the standard patterns for FastAPI routers.
Copy and adapt for new resources.
"""
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status

from src.api.dependencies import get_current_user, get_product_service
from src.models.user import User
from src.schemas.product import (
    ProductCreate,
    ProductListResponse,
    ProductResponse,
    ProductUpdate,
)
from src.services.product_service import ProductService

# Router configuration
router = APIRouter(prefix="/products", tags=["products"])


# ============================================================
# List (GET /)
# ============================================================
@router.get("", response_model=ProductListResponse)
async def list_products(
    skip: int = Query(default=0, ge=0, description="Number of items to skip"),
    limit: int = Query(default=20, ge=1, le=100, description="Max items to return"),
    category_id: UUID | None = Query(default=None, description="Filter by category"),
    search: str | None = Query(default=None, min_length=1, description="Search term"),
    service: ProductService = Depends(get_product_service),
    current_user: User = Depends(get_current_user),
) -> ProductListResponse:
    """
    List all products with pagination and optional filters.

    - **skip**: Number of items to skip (for pagination)
    - **limit**: Maximum items to return (1-100)
    - **category_id**: Filter by category UUID
    - **search**: Search in product name/description
    """
    products, total = await service.list(
        skip=skip,
        limit=limit,
        category_id=category_id,
        search=search,
    )
    return ProductListResponse(
        items=[ProductResponse.model_validate(p) for p in products],
        total=total,
        skip=skip,
        limit=limit,
    )


# ============================================================
# Get by ID (GET /{id})
# ============================================================
@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(
    product_id: UUID,
    service: ProductService = Depends(get_product_service),
    current_user: User = Depends(get_current_user),
) -> ProductResponse:
    """
    Get a single product by ID.

    Raises 404 if product not found.
    """
    product = await service.get_by_id(product_id)
    return ProductResponse.model_validate(product)


# ============================================================
# Create (POST /)
# ============================================================
@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    response_model=ProductResponse,
)
async def create_product(
    data: ProductCreate,
    service: ProductService = Depends(get_product_service),
    current_user: User = Depends(get_current_user),
) -> ProductResponse:
    """
    Create a new product.

    - **name**: Product display name (required)
    - **sku**: Unique stock keeping unit (required)
    - **price**: Price in USD, must be positive (required)
    - **category_id**: Category UUID (required)
    - **description**: Optional description

    Returns 201 Created with the new product.
    Returns 409 Conflict if SKU already exists.
    """
    product = await service.create(data, created_by=current_user.id)
    return ProductResponse.model_validate(product)


# ============================================================
# Update (PATCH /{id})
# ============================================================
@router.patch("/{product_id}", response_model=ProductResponse)
async def update_product(
    product_id: UUID,
    data: ProductUpdate,
    service: ProductService = Depends(get_product_service),
    current_user: User = Depends(get_current_user),
) -> ProductResponse:
    """
    Partially update a product.

    Only provided fields are updated. Omitted fields remain unchanged.

    Raises 404 if product not found.
    """
    product = await service.update(
        product_id,
        data,
        updated_by=current_user.id,
    )
    return ProductResponse.model_validate(product)


# ============================================================
# Delete (DELETE /{id})
# ============================================================
@router.delete("/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_product(
    product_id: UUID,
    service: ProductService = Depends(get_product_service),
    current_user: User = Depends(get_current_user),
) -> None:
    """
    Delete a product.

    Raises 404 if product not found.
    """
    await service.delete(product_id)


# ============================================================
# Custom Actions
# ============================================================
@router.post("/{product_id}/publish", response_model=ProductResponse)
async def publish_product(
    product_id: UUID,
    service: ProductService = Depends(get_product_service),
    current_user: User = Depends(get_current_user),
) -> ProductResponse:
    """
    Publish a product (make it visible to customers).

    This is a custom action that changes product state.
    """
    product = await service.publish(product_id, published_by=current_user.id)
    return ProductResponse.model_validate(product)


# ============================================================
# Nested Resources
# ============================================================
@router.get("/{product_id}/reviews")
async def list_product_reviews(
    product_id: UUID,
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
    service: ProductService = Depends(get_product_service),
    current_user: User = Depends(get_current_user),
):
    """
    List reviews for a specific product.
    """
    # Verify product exists first
    await service.get_by_id(product_id)
    return await service.get_reviews(product_id, skip=skip, limit=limit)
