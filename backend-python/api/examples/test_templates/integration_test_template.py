"""
Integration Test Template - pytest Integration Tests with Real Database

This template demonstrates the standard patterns for integration testing.
Integration tests use a real database to verify full stack behavior.
"""
import pytest
from decimal import Decimal
from uuid import uuid4

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.models.product import Product
from src.models.category import Category
from src.models.user import User


# ============================================================
# Fixtures
# ============================================================
@pytest.fixture
async def category(db: AsyncSession) -> Category:
    """Create a test category in the database."""
    category = Category(
        id=uuid4(),
        name="Electronics",
        slug="electronics",
    )
    db.add(category)
    await db.flush()
    return category


@pytest.fixture
async def product(
    db: AsyncSession,
    category: Category,
    test_user: User,
) -> Product:
    """Create a test product in the database."""
    product = Product(
        id=uuid4(),
        name="Test Product",
        sku="TEST-001",
        price=Decimal("29.99"),
        category_id=category.id,
        created_by=test_user.id,
    )
    db.add(product)
    await db.flush()
    return product


@pytest.fixture
def product_factory(db: AsyncSession, category: Category, test_user: User):
    """Factory fixture to create products with custom attributes."""

    async def create_product(**kwargs) -> Product:
        defaults = {
            "id": uuid4(),
            "name": "Factory Product",
            "sku": f"SKU-{uuid4().hex[:8].upper()}",
            "price": Decimal("29.99"),
            "category_id": category.id,
            "created_by": test_user.id,
        }
        defaults.update(kwargs)
        product = Product(**defaults)
        db.add(product)
        await db.flush()
        return product

    return create_product


# ============================================================
# Test Class: List Products
# ============================================================
class TestListProducts:
    """Integration tests for listing products."""

    async def test_returns_empty_list_when_no_products(
        self,
        client: AsyncClient,
        auth_headers: dict,
    ):
        """Should return empty list when no products exist."""
        response = await client.get(
            "/api/v1/products",
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.json()
        assert data["items"] == []
        assert data["total"] == 0

    async def test_returns_existing_products(
        self,
        client: AsyncClient,
        auth_headers: dict,
        product: Product,
    ):
        """Should return products that exist in database."""
        response = await client.get(
            "/api/v1/products",
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 1
        assert data["items"][0]["sku"] == "TEST-001"
        assert data["items"][0]["name"] == "Test Product"

    async def test_pagination_works_correctly(
        self,
        client: AsyncClient,
        auth_headers: dict,
        product_factory,
    ):
        """Should paginate results correctly."""
        # Create 25 products
        for i in range(25):
            await product_factory(name=f"Product {i:02d}")

        # First page
        response = await client.get(
            "/api/v1/products?skip=0&limit=10",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["items"]) == 10
        assert data["total"] == 25

        # Second page
        response = await client.get(
            "/api/v1/products?skip=10&limit=10",
            headers=auth_headers,
        )
        data = response.json()
        assert len(data["items"]) == 10

        # Last page
        response = await client.get(
            "/api/v1/products?skip=20&limit=10",
            headers=auth_headers,
        )
        data = response.json()
        assert len(data["items"]) == 5

    async def test_filters_by_category(
        self,
        client: AsyncClient,
        auth_headers: dict,
        db: AsyncSession,
        product: Product,
        test_user: User,
    ):
        """Should filter products by category."""
        # Create another category and product
        other_category = Category(id=uuid4(), name="Books", slug="books")
        db.add(other_category)
        await db.flush()

        other_product = Product(
            name="Other Product",
            sku="OTHER-001",
            price=Decimal("19.99"),
            category_id=other_category.id,
            created_by=test_user.id,
        )
        db.add(other_product)
        await db.flush()

        # Filter by first category
        response = await client.get(
            f"/api/v1/products?category_id={product.category_id}",
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 1
        assert data["items"][0]["sku"] == "TEST-001"


# ============================================================
# Test Class: Get Product
# ============================================================
class TestGetProduct:
    """Integration tests for getting a single product."""

    async def test_returns_product_by_id(
        self,
        client: AsyncClient,
        auth_headers: dict,
        product: Product,
    ):
        """Should return product when it exists."""
        response = await client.get(
            f"/api/v1/products/{product.id}",
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == str(product.id)
        assert data["name"] == "Test Product"
        assert data["sku"] == "TEST-001"

    async def test_returns_404_for_nonexistent_product(
        self,
        client: AsyncClient,
        auth_headers: dict,
    ):
        """Should return 404 when product doesn't exist."""
        response = await client.get(
            f"/api/v1/products/{uuid4()}",
            headers=auth_headers,
        )

        assert response.status_code == 404


# ============================================================
# Test Class: Create Product
# ============================================================
class TestCreateProduct:
    """Integration tests for creating products."""

    async def test_creates_product_with_valid_data(
        self,
        client: AsyncClient,
        auth_headers: dict,
        category: Category,
        db: AsyncSession,
    ):
        """Should create product and persist to database."""
        response = await client.post(
            "/api/v1/products",
            headers=auth_headers,
            json={
                "name": "New Product",
                "sku": "NEW-001",
                "price": "49.99",
                "category_id": str(category.id),
                "description": "A great product",
            },
        )

        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "New Product"
        assert data["sku"] == "NEW-001"
        assert "id" in data

        # Verify persisted to database
        result = await db.execute(
            select(Product).where(Product.id == data["id"])
        )
        product = result.scalar_one_or_none()
        assert product is not None
        assert product.name == "New Product"

    async def test_returns_409_for_duplicate_sku(
        self,
        client: AsyncClient,
        auth_headers: dict,
        product: Product,
        category: Category,
    ):
        """Should return 409 when SKU already exists."""
        response = await client.post(
            "/api/v1/products",
            headers=auth_headers,
            json={
                "name": "Another Product",
                "sku": product.sku,  # Duplicate
                "price": "19.99",
                "category_id": str(category.id),
            },
        )

        assert response.status_code == 409

    async def test_returns_422_for_invalid_data(
        self,
        client: AsyncClient,
        auth_headers: dict,
    ):
        """Should return 422 for validation errors."""
        response = await client.post(
            "/api/v1/products",
            headers=auth_headers,
            json={
                "name": "",  # Invalid: empty
                "sku": "INVALID",
                "price": "-10",  # Invalid: negative
            },
        )

        assert response.status_code == 422


# ============================================================
# Test Class: Update Product
# ============================================================
class TestUpdateProduct:
    """Integration tests for updating products."""

    async def test_updates_product_fields(
        self,
        client: AsyncClient,
        auth_headers: dict,
        product: Product,
        db: AsyncSession,
    ):
        """Should update product and persist changes."""
        response = await client.patch(
            f"/api/v1/products/{product.id}",
            headers=auth_headers,
            json={"name": "Updated Name", "price": "39.99"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Updated Name"
        assert data["price"] == "39.99"

        # Verify persisted
        await db.refresh(product)
        assert product.name == "Updated Name"
        assert product.price == Decimal("39.99")

    async def test_partial_update_preserves_other_fields(
        self,
        client: AsyncClient,
        auth_headers: dict,
        product: Product,
    ):
        """Should only update provided fields."""
        original_price = str(product.price)

        response = await client.patch(
            f"/api/v1/products/{product.id}",
            headers=auth_headers,
            json={"name": "Updated Name"},  # Only updating name
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Updated Name"
        assert data["price"] == original_price  # Unchanged

    async def test_returns_404_for_nonexistent_product(
        self,
        client: AsyncClient,
        auth_headers: dict,
    ):
        """Should return 404 when product doesn't exist."""
        response = await client.patch(
            f"/api/v1/products/{uuid4()}",
            headers=auth_headers,
            json={"name": "Updated"},
        )

        assert response.status_code == 404


# ============================================================
# Test Class: Delete Product
# ============================================================
class TestDeleteProduct:
    """Integration tests for deleting products."""

    async def test_deletes_product(
        self,
        client: AsyncClient,
        auth_headers: dict,
        product: Product,
        db: AsyncSession,
    ):
        """Should delete product from database."""
        response = await client.delete(
            f"/api/v1/products/{product.id}",
            headers=auth_headers,
        )

        assert response.status_code == 204

        # Verify deleted
        result = await db.execute(
            select(Product).where(Product.id == product.id)
        )
        assert result.scalar_one_or_none() is None

    async def test_returns_404_for_nonexistent_product(
        self,
        client: AsyncClient,
        auth_headers: dict,
    ):
        """Should return 404 when product doesn't exist."""
        response = await client.delete(
            f"/api/v1/products/{uuid4()}",
            headers=auth_headers,
        )

        assert response.status_code == 404


# ============================================================
# Test Class: Authentication
# ============================================================
class TestAuthentication:
    """Integration tests for authentication requirements."""

    async def test_returns_401_without_token(
        self,
        client: AsyncClient,
    ):
        """Should require authentication."""
        response = await client.get("/api/v1/products")

        assert response.status_code == 401

    async def test_returns_401_with_invalid_token(
        self,
        client: AsyncClient,
    ):
        """Should reject invalid tokens."""
        response = await client.get(
            "/api/v1/products",
            headers={"Authorization": "Bearer invalid-token"},
        )

        assert response.status_code == 401


# ============================================================
# Test Class: Authorization
# ============================================================
class TestAuthorization:
    """Integration tests for authorization."""

    async def test_admin_can_access_admin_endpoints(
        self,
        client: AsyncClient,
        admin_auth_headers: dict,
    ):
        """Admin users should access admin endpoints."""
        response = await client.get(
            "/api/v1/admin/users",
            headers=admin_auth_headers,
        )

        assert response.status_code == 200

    async def test_regular_user_cannot_access_admin_endpoints(
        self,
        client: AsyncClient,
        auth_headers: dict,
    ):
        """Regular users should be denied admin access."""
        response = await client.get(
            "/api/v1/admin/users",
            headers=auth_headers,
        )

        assert response.status_code == 403


# ============================================================
# Test Class: Full Request Cycle
# ============================================================
class TestFullCycle:
    """Tests that verify complete CRUD operations."""

    async def test_create_read_update_delete_cycle(
        self,
        client: AsyncClient,
        auth_headers: dict,
        category: Category,
    ):
        """Should handle complete CRUD lifecycle."""
        # Create
        create_response = await client.post(
            "/api/v1/products",
            headers=auth_headers,
            json={
                "name": "Lifecycle Product",
                "sku": "LIFE-001",
                "price": "29.99",
                "category_id": str(category.id),
            },
        )
        assert create_response.status_code == 201
        product_id = create_response.json()["id"]

        # Read
        get_response = await client.get(
            f"/api/v1/products/{product_id}",
            headers=auth_headers,
        )
        assert get_response.status_code == 200
        assert get_response.json()["name"] == "Lifecycle Product"

        # Update
        update_response = await client.patch(
            f"/api/v1/products/{product_id}",
            headers=auth_headers,
            json={"name": "Updated Lifecycle Product"},
        )
        assert update_response.status_code == 200
        assert update_response.json()["name"] == "Updated Lifecycle Product"

        # Delete
        delete_response = await client.delete(
            f"/api/v1/products/{product_id}",
            headers=auth_headers,
        )
        assert delete_response.status_code == 204

        # Verify deleted
        final_response = await client.get(
            f"/api/v1/products/{product_id}",
            headers=auth_headers,
        )
        assert final_response.status_code == 404
