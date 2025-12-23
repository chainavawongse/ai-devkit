# Integration Testing

## Overview

Integration tests verify that components work together correctly with real dependencies (database, external services). They complement unit tests by testing the full stack.

## Setup

### Dependencies

```bash
uv add --dev pytest pytest-asyncio httpx testcontainers[postgres]
```

### Test Database Options

1. **Testcontainers** (recommended) - Spin up isolated PostgreSQL container per test run
2. **Dedicated test database** - Use separate database instance
3. **SQLite in-memory** - Fast but doesn't test PostgreSQL-specific features

### Directory Structure

```
tests/
├── conftest.py
├── unit/
│   └── ...
└── integration/
    ├── __init__.py
    ├── conftest.py           # Integration test fixtures
    └── api/
        ├── __init__.py
        ├── test_products_api.py
        └── test_auth_api.py
```

## Fixtures with Testcontainers

```python
# tests/integration/conftest.py
import pytest
import asyncio
from collections.abc import AsyncGenerator
from uuid import uuid4

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from testcontainers.postgres import PostgresContainer
from httpx import AsyncClient, ASGITransport

from src.main import app
from src.models.base import Base
from src.models.user import User, UserRole
from src.models.product import Product
from src.core.database import get_db
from src.core.security import create_access_token


@pytest.fixture(scope="session")
def event_loop():
    """Create event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
def postgres_container():
    """Start PostgreSQL container for the test session."""
    with PostgresContainer("postgres:16") as postgres:
        yield postgres


@pytest.fixture(scope="session")
async def engine(postgres_container):
    """Create async engine connected to test container."""
    # Build async URL
    url = postgres_container.get_connection_url()
    async_url = url.replace("postgresql://", "postgresql+asyncpg://")

    engine = create_async_engine(async_url, echo=False)

    # Create all tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield engine

    await engine.dispose()


@pytest.fixture
async def db(engine) -> AsyncGenerator[AsyncSession, None]:
    """Create a fresh database session for each test with rollback."""
    async_session_factory = async_sessionmaker(engine, class_=AsyncSession)

    async with async_session_factory() as session:
        # Start a savepoint
        async with session.begin():
            yield session
            # Rollback to savepoint after test
            await session.rollback()


@pytest.fixture
async def client(db: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Create test client with overridden database dependency."""

    async def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        yield client

    app.dependency_overrides.clear()


@pytest.fixture
async def test_user(db: AsyncSession) -> User:
    """Create a test user in the database."""
    user = User(
        id=uuid4(),
        email="test@example.com",
        name="Test User",
        password_hash="$2b$12$...",  # Hashed "password"
        role=UserRole.USER,
        is_active=True,
    )
    db.add(user)
    await db.flush()
    return user


@pytest.fixture
async def admin_user(db: AsyncSession) -> User:
    """Create an admin user in the database."""
    user = User(
        id=uuid4(),
        email="admin@example.com",
        name="Admin User",
        password_hash="$2b$12$...",
        role=UserRole.ADMIN,
        is_active=True,
    )
    db.add(user)
    await db.flush()
    return user


@pytest.fixture
def auth_headers(test_user: User) -> dict[str, str]:
    """Generate auth headers for test user."""
    token = create_access_token(test_user.id)
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def admin_auth_headers(admin_user: User) -> dict[str, str]:
    """Generate auth headers for admin user."""
    token = create_access_token(admin_user.id)
    return {"Authorization": f"Bearer {token}"}
```

## API Integration Tests

### Testing CRUD Operations

```python
# tests/integration/api/test_products_api.py
import pytest
from uuid import uuid4
from decimal import Decimal
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from src.models.product import Product
from src.models.category import Category


@pytest.fixture
async def category(db: AsyncSession) -> Category:
    """Create a test category."""
    category = Category(id=uuid4(), name="Electronics")
    db.add(category)
    await db.flush()
    return category


@pytest.fixture
async def product(db: AsyncSession, category: Category, test_user) -> Product:
    """Create a test product."""
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


class TestListProducts:
    async def test_returns_empty_list_initially(
        self,
        client: AsyncClient,
        auth_headers: dict,
    ):
        response = await client.get("/api/v1/products", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert data["items"] == []
        assert data["total"] == 0

    async def test_returns_created_products(
        self,
        client: AsyncClient,
        auth_headers: dict,
        product: Product,
    ):
        response = await client.get("/api/v1/products", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 1
        assert data["items"][0]["sku"] == "TEST-001"

    async def test_pagination_works(
        self,
        client: AsyncClient,
        auth_headers: dict,
        db: AsyncSession,
        category: Category,
        test_user,
    ):
        # Create multiple products
        for i in range(25):
            product = Product(
                name=f"Product {i}",
                sku=f"SKU-{i:03d}",
                price=Decimal("10.00"),
                category_id=category.id,
                created_by=test_user.id,
            )
            db.add(product)
        await db.flush()

        # Test first page
        response = await client.get(
            "/api/v1/products?skip=0&limit=10",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["items"]) == 10
        assert data["total"] == 25

        # Test second page
        response = await client.get(
            "/api/v1/products?skip=10&limit=10",
            headers=auth_headers,
        )
        data = response.json()
        assert len(data["items"]) == 10


class TestGetProduct:
    async def test_returns_product_by_id(
        self,
        client: AsyncClient,
        auth_headers: dict,
        product: Product,
    ):
        response = await client.get(
            f"/api/v1/products/{product.id}",
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == str(product.id)
        assert data["name"] == "Test Product"

    async def test_returns_404_for_nonexistent(
        self,
        client: AsyncClient,
        auth_headers: dict,
    ):
        response = await client.get(
            f"/api/v1/products/{uuid4()}",
            headers=auth_headers,
        )

        assert response.status_code == 404


class TestCreateProduct:
    async def test_creates_product_with_valid_data(
        self,
        client: AsyncClient,
        auth_headers: dict,
        category: Category,
    ):
        response = await client.post(
            "/api/v1/products",
            headers=auth_headers,
            json={
                "name": "New Product",
                "sku": "NEW-001",
                "price": "49.99",
                "category_id": str(category.id),
            },
        )

        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "New Product"
        assert data["sku"] == "NEW-001"
        assert "id" in data

    async def test_returns_409_for_duplicate_sku(
        self,
        client: AsyncClient,
        auth_headers: dict,
        product: Product,
        category: Category,
    ):
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
        response = await client.post(
            "/api/v1/products",
            headers=auth_headers,
            json={
                "name": "",  # Invalid
                "price": "-10",  # Invalid
            },
        )

        assert response.status_code == 422


class TestUpdateProduct:
    async def test_updates_product_fields(
        self,
        client: AsyncClient,
        auth_headers: dict,
        product: Product,
    ):
        response = await client.patch(
            f"/api/v1/products/{product.id}",
            headers=auth_headers,
            json={"name": "Updated Name", "price": "39.99"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Updated Name"
        assert data["price"] == "39.99"

    async def test_returns_404_for_nonexistent(
        self,
        client: AsyncClient,
        auth_headers: dict,
    ):
        response = await client.patch(
            f"/api/v1/products/{uuid4()}",
            headers=auth_headers,
            json={"name": "Updated"},
        )

        assert response.status_code == 404


class TestDeleteProduct:
    async def test_deletes_product(
        self,
        client: AsyncClient,
        auth_headers: dict,
        product: Product,
    ):
        response = await client.delete(
            f"/api/v1/products/{product.id}",
            headers=auth_headers,
        )

        assert response.status_code == 204

        # Verify deleted
        get_response = await client.get(
            f"/api/v1/products/{product.id}",
            headers=auth_headers,
        )
        assert get_response.status_code == 404
```

### Testing Authentication

```python
# tests/integration/api/test_auth_api.py
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from src.models.user import User
from src.core.security import hash_password


@pytest.fixture
async def registered_user(db: AsyncSession) -> User:
    """Create a user with known password."""
    user = User(
        email="registered@example.com",
        name="Registered User",
        password_hash=hash_password("correctpassword"),
        is_active=True,
    )
    db.add(user)
    await db.flush()
    return user


class TestLogin:
    async def test_returns_tokens_for_valid_credentials(
        self,
        client: AsyncClient,
        registered_user: User,
    ):
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": registered_user.email,
                "password": "correctpassword",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"

    async def test_returns_401_for_wrong_password(
        self,
        client: AsyncClient,
        registered_user: User,
    ):
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": registered_user.email,
                "password": "wrongpassword",
            },
        )

        assert response.status_code == 401

    async def test_returns_401_for_nonexistent_user(
        self,
        client: AsyncClient,
    ):
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": "nonexistent@example.com",
                "password": "anypassword",
            },
        )

        assert response.status_code == 401


class TestProtectedRoutes:
    async def test_returns_401_without_token(
        self,
        client: AsyncClient,
    ):
        response = await client.get("/api/v1/products")

        assert response.status_code == 401

    async def test_returns_401_with_invalid_token(
        self,
        client: AsyncClient,
    ):
        response = await client.get(
            "/api/v1/products",
            headers={"Authorization": "Bearer invalid-token"},
        )

        assert response.status_code == 401

    async def test_allows_access_with_valid_token(
        self,
        client: AsyncClient,
        auth_headers: dict,
    ):
        response = await client.get("/api/v1/products", headers=auth_headers)

        assert response.status_code == 200
```

### Testing Authorization

```python
# tests/integration/api/test_admin_api.py
import pytest
from httpx import AsyncClient


class TestAdminEndpoints:
    async def test_admin_can_access_admin_routes(
        self,
        client: AsyncClient,
        admin_auth_headers: dict,
    ):
        response = await client.get(
            "/api/v1/admin/users",
            headers=admin_auth_headers,
        )

        assert response.status_code == 200

    async def test_regular_user_cannot_access_admin_routes(
        self,
        client: AsyncClient,
        auth_headers: dict,  # Regular user
    ):
        response = await client.get(
            "/api/v1/admin/users",
            headers=auth_headers,
        )

        assert response.status_code == 403
```

## Database Verification

```python
# tests/integration/api/test_products_api.py
from sqlalchemy import select

class TestCreateProduct:
    async def test_product_persisted_to_database(
        self,
        client: AsyncClient,
        auth_headers: dict,
        category: Category,
        db: AsyncSession,
    ):
        response = await client.post(
            "/api/v1/products",
            headers=auth_headers,
            json={
                "name": "Persisted Product",
                "sku": "PERSIST-001",
                "price": "49.99",
                "category_id": str(category.id),
            },
        )

        assert response.status_code == 201
        product_id = response.json()["id"]

        # Verify in database
        result = await db.execute(
            select(Product).where(Product.id == product_id)
        )
        product = result.scalar_one_or_none()

        assert product is not None
        assert product.name == "Persisted Product"
        assert product.sku == "PERSIST-001"
```

## Testing with External Services

### Mocking External APIs

```python
# tests/integration/conftest.py
import pytest
from unittest.mock import AsyncMock
import httpx


@pytest.fixture
def mock_external_api(mocker):
    """Mock external API calls in integration tests."""
    mock_client = AsyncMock(spec=httpx.AsyncClient)

    mock_response = AsyncMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {"status": "success"}
    mock_response.raise_for_status = AsyncMock()

    mock_client.post.return_value = mock_response
    mock_client.get.return_value = mock_response

    mocker.patch(
        "src.services.external_service.get_http_client",
        return_value=mock_client,
    )

    return mock_client
```

### Using WireMock or VCR

```python
# tests/integration/conftest.py
import pytest
from pytest_recording import use_cassette


@pytest.fixture
def external_api_cassette():
    """Record/replay external API calls."""
    with use_cassette("tests/cassettes/external_api.yaml"):
        yield
```

## Running Integration Tests

```bash
# Run all integration tests
uv run pytest tests/integration -v

# Run with specific markers
uv run pytest tests/integration -m "integration" -v

# Run specific test file
uv run pytest tests/integration/api/test_products_api.py -v

# Skip slow tests
uv run pytest tests/integration -m "not slow" -v

# Run with output
uv run pytest tests/integration -v -s --tb=short
```

## Best Practices

### 1. Isolate Tests with Transaction Rollback

```python
@pytest.fixture
async def db(engine):
    async with async_session_factory() as session:
        async with session.begin():
            yield session
            await session.rollback()  # Cleanup after each test
```

### 2. Use Factory Fixtures

```python
@pytest.fixture
def product_factory(db, category, test_user):
    """Factory to create products with custom attributes."""
    async def create_product(**kwargs):
        defaults = {
            "name": "Test Product",
            "sku": f"SKU-{uuid4().hex[:8]}",
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


# Usage
async def test_something(product_factory):
    product1 = await product_factory(name="Product 1", price=Decimal("10.00"))
    product2 = await product_factory(name="Product 2", price=Decimal("20.00"))
```

### 3. Test Full Request/Response Cycle

```python
async def test_create_then_retrieve(self, client, auth_headers, category):
    # Create
    create_response = await client.post(
        "/api/v1/products",
        headers=auth_headers,
        json={"name": "Test", "sku": "TEST", "price": "10", "category_id": str(category.id)},
    )
    product_id = create_response.json()["id"]

    # Retrieve
    get_response = await client.get(
        f"/api/v1/products/{product_id}",
        headers=auth_headers,
    )

    assert get_response.status_code == 200
    assert get_response.json()["name"] == "Test"
```

### 4. Test Error Scenarios

```python
async def test_concurrent_update_conflict(self, client, auth_headers, product):
    # Simulate concurrent updates
    response1 = await client.patch(
        f"/api/v1/products/{product.id}",
        headers=auth_headers,
        json={"name": "Update 1"},
    )
    response2 = await client.patch(
        f"/api/v1/products/{product.id}",
        headers=auth_headers,
        json={"name": "Update 2"},
    )

    # Both should succeed (last write wins) or handle conflict
    assert response1.status_code == 200
    assert response2.status_code == 200
```

### 5. Keep Tests Independent

```python
# Good - each test creates its own data
async def test_one(self, client, product_factory):
    product = await product_factory(name="Test 1")
    ...

async def test_two(self, client, product_factory):
    product = await product_factory(name="Test 2")
    ...

# Avoid - tests depending on order
class_level_product_id = None  # Don't do this
```
