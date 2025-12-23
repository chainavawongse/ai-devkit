"""
Unit Test Template - pytest Unit Tests with Mocking

This template demonstrates the standard patterns for unit testing services.
Unit tests use mocks to isolate the code under test from dependencies.
"""
import pytest
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

from src.services.product_service import ProductService
from src.schemas.product import ProductCreate, ProductUpdate
from src.models.product import Product
from src.core.exceptions import NotFoundError, ConflictError, ValidationError


# ============================================================
# Fixtures
# ============================================================
@pytest.fixture
def mock_db() -> AsyncMock:
    """Create a mock database session."""
    db = AsyncMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.rollback = AsyncMock()
    db.add = MagicMock()
    db.delete = AsyncMock()
    return db


@pytest.fixture
def service(mock_db: AsyncMock) -> ProductService:
    """Create service with mocked database."""
    return ProductService(mock_db)


@pytest.fixture
def user_id():
    """Generate a user ID for tests."""
    return uuid4()


@pytest.fixture
def product_id():
    """Generate a product ID for tests."""
    return uuid4()


@pytest.fixture
def sample_product(product_id, user_id) -> Product:
    """Create a sample product for testing."""
    return Product(
        id=product_id,
        name="Test Product",
        sku="TEST-001",
        price=Decimal("29.99"),
        category_id=uuid4(),
        created_by=user_id,
    )


@pytest.fixture
def valid_create_data() -> ProductCreate:
    """Valid product creation data."""
    return ProductCreate(
        name="New Product",
        sku="NEW-001",
        price=Decimal("49.99"),
        category_id=uuid4(),
    )


# ============================================================
# Test Class: get_by_id
# ============================================================
class TestProductServiceGetById:
    """Tests for ProductService.get_by_id method."""

    async def test_returns_product_when_found(
        self,
        service: ProductService,
        mock_db: AsyncMock,
        sample_product: Product,
    ):
        """Should return product when it exists."""
        # Arrange
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = sample_product
        mock_db.execute.return_value = mock_result

        # Act
        result = await service.get_by_id(sample_product.id)

        # Assert
        assert result == sample_product
        assert result.name == "Test Product"
        mock_db.execute.assert_called_once()

    async def test_raises_not_found_when_product_missing(
        self,
        service: ProductService,
        mock_db: AsyncMock,
        product_id,
    ):
        """Should raise NotFoundError when product doesn't exist."""
        # Arrange
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        # Act & Assert
        with pytest.raises(NotFoundError) as exc_info:
            await service.get_by_id(product_id)

        assert str(product_id) in str(exc_info.value)


# ============================================================
# Test Class: create
# ============================================================
class TestProductServiceCreate:
    """Tests for ProductService.create method."""

    async def test_creates_product_with_valid_data(
        self,
        service: ProductService,
        mock_db: AsyncMock,
        valid_create_data: ProductCreate,
        user_id,
    ):
        """Should create product when data is valid and SKU is unique."""
        # Arrange - SKU doesn't exist
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
        result = await service.create(valid_create_data, created_by=user_id)

        # Assert
        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()
        mock_db.refresh.assert_called_once()
        assert added_product.name == "New Product"
        assert added_product.sku == "NEW-001"
        assert added_product.created_by == user_id

    async def test_raises_conflict_for_duplicate_sku(
        self,
        service: ProductService,
        mock_db: AsyncMock,
        valid_create_data: ProductCreate,
        sample_product: Product,
        user_id,
    ):
        """Should raise ConflictError when SKU already exists."""
        # Arrange - SKU exists
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = sample_product
        mock_db.execute.return_value = mock_result

        # Override SKU to match existing
        valid_create_data.sku = sample_product.sku

        # Act & Assert
        with pytest.raises(ConflictError) as exc_info:
            await service.create(valid_create_data, created_by=user_id)

        assert "already exists" in str(exc_info.value).lower()
        mock_db.add.assert_not_called()
        mock_db.commit.assert_not_called()

    async def test_raises_validation_error_for_invalid_price(
        self,
        service: ProductService,
        mock_db: AsyncMock,
        user_id,
    ):
        """Should raise ValidationError for invalid price."""
        # Arrange
        data = ProductCreate(
            name="Test",
            sku="TEST",
            price=Decimal("0.001"),  # Below minimum
            category_id=uuid4(),
        )

        # Mock SKU check to pass
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        # Act & Assert
        with pytest.raises(ValidationError):
            await service.create(data, created_by=user_id)


# ============================================================
# Test Class: update
# ============================================================
class TestProductServiceUpdate:
    """Tests for ProductService.update method."""

    async def test_updates_product_fields(
        self,
        service: ProductService,
        mock_db: AsyncMock,
        sample_product: Product,
        user_id,
    ):
        """Should update only provided fields."""
        # Arrange
        data = ProductUpdate(name="Updated Name", price=Decimal("39.99"))

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = sample_product
        mock_db.execute.return_value = mock_result

        # Act
        await service.update(sample_product.id, data, updated_by=user_id)

        # Assert
        assert sample_product.name == "Updated Name"
        assert sample_product.price == Decimal("39.99")
        mock_db.commit.assert_called_once()

    async def test_ignores_none_fields(
        self,
        service: ProductService,
        mock_db: AsyncMock,
        sample_product: Product,
        user_id,
    ):
        """Should not update fields that are None/not provided."""
        # Arrange
        original_price = sample_product.price
        data = ProductUpdate(name="Updated Name")  # price not provided

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = sample_product
        mock_db.execute.return_value = mock_result

        # Act
        await service.update(sample_product.id, data, updated_by=user_id)

        # Assert
        assert sample_product.name == "Updated Name"
        assert sample_product.price == original_price  # Unchanged

    async def test_raises_not_found_when_product_missing(
        self,
        service: ProductService,
        mock_db: AsyncMock,
        product_id,
        user_id,
    ):
        """Should raise NotFoundError when product doesn't exist."""
        # Arrange
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        data = ProductUpdate(name="Updated")

        # Act & Assert
        with pytest.raises(NotFoundError):
            await service.update(product_id, data, updated_by=user_id)


# ============================================================
# Test Class: delete
# ============================================================
class TestProductServiceDelete:
    """Tests for ProductService.delete method."""

    async def test_deletes_existing_product(
        self,
        service: ProductService,
        mock_db: AsyncMock,
        sample_product: Product,
    ):
        """Should delete product when it exists."""
        # Arrange
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = sample_product
        mock_db.execute.return_value = mock_result

        # Act
        await service.delete(sample_product.id)

        # Assert
        mock_db.delete.assert_called_once_with(sample_product)
        mock_db.commit.assert_called_once()

    async def test_raises_not_found_when_product_missing(
        self,
        service: ProductService,
        mock_db: AsyncMock,
        product_id,
    ):
        """Should raise NotFoundError when product doesn't exist."""
        # Arrange
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        # Act & Assert
        with pytest.raises(NotFoundError):
            await service.delete(product_id)

        mock_db.delete.assert_not_called()


# ============================================================
# Parametrized Tests
# ============================================================
class TestProductValidation:
    """Parametrized tests for validation edge cases."""

    @pytest.mark.parametrize(
        "name,expected_valid",
        [
            ("Valid Name", True),
            ("A", True),  # Min length
            ("X" * 200, True),  # Max length
            ("", False),  # Too short
            ("X" * 201, False),  # Too long
        ],
    )
    def test_name_validation(self, name: str, expected_valid: bool):
        """Test name field validation with various inputs."""
        from pydantic import ValidationError as PydanticValidationError

        data = {
            "name": name,
            "sku": "TEST-001",
            "price": "29.99",
            "category_id": str(uuid4()),
        }

        if expected_valid:
            ProductCreate(**data)  # Should not raise
        else:
            with pytest.raises(PydanticValidationError):
                ProductCreate(**data)

    @pytest.mark.parametrize(
        "price,expected_valid",
        [
            (Decimal("0.01"), True),
            (Decimal("999999.99"), True),
            (Decimal("0"), False),
            (Decimal("-1.00"), False),
        ],
    )
    def test_price_validation(self, price: Decimal, expected_valid: bool):
        """Test price field validation with various inputs."""
        from pydantic import ValidationError as PydanticValidationError

        data = {
            "name": "Test",
            "sku": "TEST-001",
            "price": str(price),
            "category_id": str(uuid4()),
        }

        if expected_valid:
            ProductCreate(**data)
        else:
            with pytest.raises(PydanticValidationError):
                ProductCreate(**data)


# ============================================================
# Testing with mocker (pytest-mock)
# ============================================================
class TestWithMocker:
    """Examples using pytest-mock's mocker fixture."""

    async def test_logs_product_creation(
        self,
        service: ProductService,
        mock_db: AsyncMock,
        valid_create_data: ProductCreate,
        user_id,
        mocker,
    ):
        """Verify logging is called when product is created."""
        # Arrange
        mock_logger = mocker.patch("src.services.product_service.logger")

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        # Act
        await service.create(valid_create_data, created_by=user_id)

        # Assert
        mock_logger.info.assert_called()
        call_args = mock_logger.info.call_args
        assert "product_created" in call_args[0]
