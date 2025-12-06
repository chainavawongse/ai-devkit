# Unit Testing

## Overview

Unit tests verify individual components in isolation using mocks for dependencies. We use pytest with pytest-asyncio for async testing and pytest-mock for mocking.

## Setup

### Dependencies

```bash
uv add --dev pytest pytest-asyncio pytest-mock pytest-cov
```

### Configuration

```toml
# pyproject.toml
[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "function"
filterwarnings = [
    "ignore::DeprecationWarning",
]
markers = [
    "unit: Unit tests",
    "integration: Integration tests",
]

[tool.coverage.run]
source = ["src"]
omit = ["src/main.py", "*/migrations/*"]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "if TYPE_CHECKING:",
    "raise NotImplementedError",
]
```

### Directory Structure

```
tests/
├── __init__.py
├── conftest.py           # Shared fixtures
├── unit/
│   ├── __init__.py
│   ├── conftest.py       # Unit test fixtures
│   ├── services/
│   │   ├── __init__.py
│   │   ├── test_product_service.py
│   │   └── test_user_service.py
│   └── api/
│       ├── __init__.py
│       └── test_products_router.py
└── integration/
    └── ...
```

## Fixtures

### Shared Fixtures

```python
# tests/conftest.py
import pytest
from uuid import uuid4
from datetime import datetime, timezone

from src.models.user import User, UserRole
from src.models.product import Product


@pytest.fixture
def user_id() -> UUID:
    return uuid4()


@pytest.fixture
def product_id() -> UUID:
    return uuid4()


@pytest.fixture
def sample_user(user_id: UUID) -> User:
    """Create a sample user for testing."""
    user = User(
        id=user_id,
        email="test@example.com",
        name="Test User",
        role=UserRole.USER,
        is_active=True,
    )
    return user


@pytest.fixture
def admin_user() -> User:
    """Create an admin user for testing."""
    return User(
        id=uuid4(),
        email="admin@example.com",
        name="Admin User",
        role=UserRole.ADMIN,
        is_active=True,
    )


@pytest.fixture
def sample_product(product_id: UUID, user_id: UUID) -> Product:
    """Create a sample product for testing."""
    return Product(
        id=product_id,
        name="Test Product",
        sku="TEST-001",
        price=Decimal("29.99"),
        category_id=uuid4(),
        created_by=user_id,
        created_at=datetime.now(timezone.utc),
    )
```

### Unit Test Fixtures

```python
# tests/unit/conftest.py
import pytest
from unittest.mock import AsyncMock, MagicMock
from sqlalchemy.ext.asyncio import AsyncSession


@pytest.fixture
def mock_db() -> AsyncMock:
    """Create a mock database session."""
    db = AsyncMock(spec=AsyncSession)
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.rollback = AsyncMock()
    db.add = MagicMock()
    db.delete = AsyncMock()
    return db


@pytest.fixture
def mock_execute_result() -> MagicMock:
    """Create a mock for db.execute() result."""
    result = MagicMock()
    result.scalar_one_or_none = MagicMock(return_value=None)
    result.scalars = MagicMock()
    result.scalars.return_value.all = MagicMock(return_value=[])
    return result
```

## Testing Services

### Basic Service Test

```python
# tests/unit/services/test_product_service.py
import pytest
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

from src.services.product_service import ProductService
from src.schemas.product import ProductCreate, ProductUpdate
from src.models.product import Product
from src.core.exceptions import NotFoundError, ConflictError


@pytest.fixture
def product_service(mock_db: AsyncMock) -> ProductService:
    """Create ProductService with mocked database."""
    return ProductService(mock_db)


class TestProductServiceGetById:
    """Tests for ProductService.get_by_id method."""

    async def test_returns_product_when_found(
        self,
        product_service: ProductService,
        mock_db: AsyncMock,
        sample_product: Product,
    ):
        # Arrange
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = sample_product
        mock_db.execute.return_value = mock_result

        # Act
        result = await product_service.get_by_id(sample_product.id)

        # Assert
        assert result == sample_product
        mock_db.execute.assert_called_once()

    async def test_raises_not_found_when_missing(
        self,
        product_service: ProductService,
        mock_db: AsyncMock,
    ):
        # Arrange
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        # Act & Assert
        with pytest.raises(NotFoundError) as exc_info:
            await product_service.get_by_id(uuid4())

        assert "not found" in str(exc_info.value).lower()


class TestProductServiceCreate:
    """Tests for ProductService.create method."""

    async def test_creates_product_with_valid_data(
        self,
        product_service: ProductService,
        mock_db: AsyncMock,
        user_id: UUID,
    ):
        # Arrange
        data = ProductCreate(
            name="New Product",
            sku="NEW-001",
            price=Decimal("49.99"),
            category_id=uuid4(),
        )

        # Mock SKU uniqueness check
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        # Capture the added product
        added_product = None
        def capture_add(product):
            nonlocal added_product
            added_product = product
        mock_db.add.side_effect = capture_add

        # Act
        result = await product_service.create(data, created_by=user_id)

        # Assert
        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()
        assert added_product.name == "New Product"
        assert added_product.sku == "NEW-001"
        assert added_product.created_by == user_id

    async def test_raises_conflict_for_duplicate_sku(
        self,
        product_service: ProductService,
        mock_db: AsyncMock,
        sample_product: Product,
        user_id: UUID,
    ):
        # Arrange
        data = ProductCreate(
            name="New Product",
            sku=sample_product.sku,  # Duplicate SKU
            price=Decimal("49.99"),
            category_id=uuid4(),
        )

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = sample_product  # SKU exists
        mock_db.execute.return_value = mock_result

        # Act & Assert
        with pytest.raises(ConflictError):
            await product_service.create(data, created_by=user_id)

        mock_db.add.assert_not_called()
        mock_db.commit.assert_not_called()


class TestProductServiceUpdate:
    """Tests for ProductService.update method."""

    async def test_updates_product_fields(
        self,
        product_service: ProductService,
        mock_db: AsyncMock,
        sample_product: Product,
    ):
        # Arrange
        data = ProductUpdate(name="Updated Name", price=Decimal("39.99"))

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = sample_product
        mock_db.execute.return_value = mock_result

        # Act
        result = await product_service.update(
            sample_product.id,
            data,
            updated_by=uuid4(),
        )

        # Assert
        assert sample_product.name == "Updated Name"
        assert sample_product.price == Decimal("39.99")
        mock_db.commit.assert_called_once()

    async def test_ignores_none_fields(
        self,
        product_service: ProductService,
        mock_db: AsyncMock,
        sample_product: Product,
    ):
        # Arrange
        original_price = sample_product.price
        data = ProductUpdate(name="Updated Name")  # price not provided

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = sample_product
        mock_db.execute.return_value = mock_result

        # Act
        await product_service.update(sample_product.id, data, updated_by=uuid4())

        # Assert
        assert sample_product.name == "Updated Name"
        assert sample_product.price == original_price  # Unchanged
```

## Testing with Mocks

### Mocking External Services

```python
# tests/unit/services/test_order_service.py
import pytest
from unittest.mock import AsyncMock, patch
import httpx

from src.services.order_service import OrderService


@pytest.fixture
def mock_http_client() -> AsyncMock:
    """Create a mock HTTP client."""
    client = AsyncMock(spec=httpx.AsyncClient)
    return client


@pytest.fixture
def order_service(mock_db: AsyncMock, mock_http_client: AsyncMock) -> OrderService:
    return OrderService(
        db=mock_db,
        http_client=mock_http_client,
        settings=MagicMock(fulfillment_api_url="https://api.example.com"),
    )


class TestOrderServiceCreate:
    async def test_notifies_fulfillment_service(
        self,
        order_service: OrderService,
        mock_db: AsyncMock,
        mock_http_client: AsyncMock,
    ):
        # Arrange
        data = OrderCreate(items=[OrderItemCreate(product_id=uuid4(), quantity=2)])

        mock_response = MagicMock()
        mock_response.raise_for_status = MagicMock()
        mock_http_client.post.return_value = mock_response

        # Act
        await order_service.create(data, user_id=uuid4())

        # Assert
        mock_http_client.post.assert_called_once()
        call_args = mock_http_client.post.call_args
        assert "orders" in call_args[0][0]

    async def test_handles_fulfillment_service_failure(
        self,
        order_service: OrderService,
        mock_db: AsyncMock,
        mock_http_client: AsyncMock,
    ):
        # Arrange
        data = OrderCreate(items=[OrderItemCreate(product_id=uuid4(), quantity=2)])
        mock_http_client.post.side_effect = httpx.HTTPError("Connection failed")

        # Act & Assert - depends on implementation
        # Either raises or handles gracefully
        with pytest.raises(ExternalServiceError):
            await order_service.create(data, user_id=uuid4())
```

### Using pytest-mock

```python
# tests/unit/services/test_auth_service.py
import pytest
from src.services.auth_service import AuthService


class TestAuthService:
    async def test_login_success(self, mocker, mock_db):
        # Arrange
        mock_verify = mocker.patch(
            "src.services.auth_service.verify_password",
            return_value=True,
        )
        mock_create_token = mocker.patch(
            "src.services.auth_service.create_access_token",
            return_value="mock-token",
        )

        service = AuthService(mock_db)
        user = User(id=uuid4(), password_hash="hashed")

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = user
        mock_db.execute.return_value = mock_result

        # Act
        result = await service.login("test@example.com", "password")

        # Assert
        mock_verify.assert_called_once_with("password", "hashed")
        mock_create_token.assert_called_once()
        assert result.access_token == "mock-token"
```

## Testing Routers

### Router Unit Tests

```python
# tests/unit/api/test_products_router.py
import pytest
from unittest.mock import AsyncMock, MagicMock
from fastapi.testclient import TestClient
from fastapi import FastAPI

from src.api.routes.products import router
from src.api.dependencies import get_product_service, get_current_user
from src.services.product_service import ProductService
from src.models.user import User


@pytest.fixture
def mock_product_service() -> AsyncMock:
    return AsyncMock(spec=ProductService)


@pytest.fixture
def mock_user(sample_user: User) -> User:
    return sample_user


@pytest.fixture
def client(
    mock_product_service: AsyncMock,
    mock_user: User,
) -> TestClient:
    """Create test client with mocked dependencies."""
    app = FastAPI()
    app.include_router(router)

    # Override dependencies
    app.dependency_overrides[get_product_service] = lambda: mock_product_service
    app.dependency_overrides[get_current_user] = lambda: mock_user

    return TestClient(app)


class TestListProducts:
    def test_returns_products_list(
        self,
        client: TestClient,
        mock_product_service: AsyncMock,
        sample_product: Product,
    ):
        # Arrange
        mock_product_service.list.return_value = ([sample_product], 1)

        # Act
        response = client.get("/products")

        # Assert
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 1
        assert len(data["items"]) == 1
        assert data["items"][0]["sku"] == sample_product.sku

    def test_accepts_pagination_params(
        self,
        client: TestClient,
        mock_product_service: AsyncMock,
    ):
        # Arrange
        mock_product_service.list.return_value = ([], 0)

        # Act
        response = client.get("/products?skip=10&limit=5")

        # Assert
        assert response.status_code == 200
        mock_product_service.list.assert_called_with(skip=10, limit=5)


class TestCreateProduct:
    def test_creates_product_with_valid_data(
        self,
        client: TestClient,
        mock_product_service: AsyncMock,
        mock_user: User,
        sample_product: Product,
    ):
        # Arrange
        mock_product_service.create.return_value = sample_product

        # Act
        response = client.post(
            "/products",
            json={
                "name": "New Product",
                "sku": "NEW-001",
                "price": "49.99",
                "category_id": str(uuid4()),
            },
        )

        # Assert
        assert response.status_code == 201
        mock_product_service.create.assert_called_once()

    def test_returns_422_for_invalid_data(
        self,
        client: TestClient,
        mock_product_service: AsyncMock,
    ):
        # Act
        response = client.post(
            "/products",
            json={
                "name": "",  # Invalid: empty name
                "price": -10,  # Invalid: negative price
            },
        )

        # Assert
        assert response.status_code == 422
        mock_product_service.create.assert_not_called()
```

## Parametrized Tests

```python
# tests/unit/test_validators.py
import pytest
from decimal import Decimal
from src.schemas.product import ProductCreate


class TestProductCreateValidation:
    @pytest.mark.parametrize(
        "name,expected_valid",
        [
            ("Valid Name", True),
            ("A", True),  # Min length 1
            ("", False),  # Empty not allowed
            ("X" * 200, True),  # Max length 200
            ("X" * 201, False),  # Over max length
        ],
    )
    def test_name_validation(self, name: str, expected_valid: bool):
        data = {
            "name": name,
            "sku": "TEST-001",
            "price": "29.99",
            "category_id": str(uuid4()),
        }

        if expected_valid:
            ProductCreate(**data)  # Should not raise
        else:
            with pytest.raises(ValidationError):
                ProductCreate(**data)

    @pytest.mark.parametrize(
        "price,expected_valid",
        [
            (Decimal("0.01"), True),
            (Decimal("999999.99"), True),
            (Decimal("0"), False),
            (Decimal("-1"), False),
        ],
    )
    def test_price_validation(self, price: Decimal, expected_valid: bool):
        data = {
            "name": "Test",
            "sku": "TEST-001",
            "price": str(price),
            "category_id": str(uuid4()),
        }

        if expected_valid:
            ProductCreate(**data)
        else:
            with pytest.raises(ValidationError):
                ProductCreate(**data)
```

## Running Tests

```bash
# Run all unit tests
uv run pytest tests/unit -v

# Run with coverage
uv run pytest tests/unit --cov=src --cov-report=html

# Run specific test file
uv run pytest tests/unit/services/test_product_service.py -v

# Run specific test class
uv run pytest tests/unit/services/test_product_service.py::TestProductServiceCreate -v

# Run tests matching pattern
uv run pytest tests/unit -k "create" -v

# Run with output
uv run pytest tests/unit -v -s
```

## Best Practices

### 1. Arrange-Act-Assert Pattern

```python
async def test_creates_product(self, service, mock_db):
    # Arrange - set up test data and mocks
    data = ProductCreate(...)
    mock_db.execute.return_value = ...

    # Act - call the method under test
    result = await service.create(data)

    # Assert - verify the outcome
    assert result.name == data.name
    mock_db.commit.assert_called_once()
```

### 2. One Assertion Focus Per Test

```python
# Good - focused tests
async def test_create_returns_product_with_correct_name(self): ...
async def test_create_commits_to_database(self): ...
async def test_create_raises_conflict_for_duplicate_sku(self): ...

# Avoid - multiple unrelated assertions
async def test_create(self):
    result = await service.create(data)
    assert result.name == data.name
    assert result.price == data.price
    mock_db.commit.assert_called_once()
    assert result.created_at is not None
```

### 3. Descriptive Test Names

```python
# Good - describes scenario and expectation
async def test_get_by_id_with_nonexistent_id_raises_not_found_error(self): ...
async def test_update_with_partial_data_only_updates_provided_fields(self): ...

# Avoid - vague names
async def test_get_by_id(self): ...
async def test_update_works(self): ...
```

### 4. Test Edge Cases

```python
class TestProductServiceList:
    async def test_returns_empty_list_when_no_products(self): ...
    async def test_handles_large_skip_value(self): ...
    async def test_respects_limit_parameter(self): ...
    async def test_returns_total_count_correctly(self): ...
```

### 5. Keep Tests Independent

```python
# Good - each test creates its own data
async def test_one(self, sample_product):
    # Uses fixture, doesn't modify shared state
    ...

async def test_two(self, sample_product):
    # Gets fresh fixture
    ...

# Avoid - shared mutable state
class_level_product = None  # Don't do this

async def test_one(self):
    global class_level_product
    class_level_product = create_product()

async def test_two(self):
    # Depends on test_one running first - fragile!
    assert class_level_product is not None
```
