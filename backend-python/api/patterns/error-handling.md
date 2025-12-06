# Error Handling

## Overview

This guide covers exception hierarchy, HTTP error responses, and error handling patterns for FastAPI applications.

## Exception Hierarchy

```python
# src/core/exceptions.py
from typing import Any


class AppError(Exception):
    """Base exception for application errors."""

    def __init__(
        self,
        message: str,
        code: str | None = None,
        details: dict[str, Any] | None = None,
    ):
        self.message = message
        self.code = code or self.__class__.__name__
        self.details = details or {}
        super().__init__(message)


class NotFoundError(AppError):
    """Resource not found."""
    pass


class ConflictError(AppError):
    """Resource conflict (e.g., duplicate)."""
    pass


class ValidationError(AppError):
    """Business validation failed."""
    pass


class AuthenticationError(AppError):
    """Authentication failed."""
    pass


class AuthorizationError(AppError):
    """Permission denied."""
    pass


class ExternalServiceError(AppError):
    """External service call failed."""
    pass
```

## Exception Handlers

Register global exception handlers to convert domain exceptions to HTTP responses:

```python
# src/core/exception_handlers.py
from fastapi import Request, status
from fastapi.responses import JSONResponse
from src.core.exceptions import (
    AppError,
    NotFoundError,
    ConflictError,
    ValidationError,
    AuthenticationError,
    AuthorizationError,
    ExternalServiceError,
)
import structlog

logger = structlog.get_logger()


async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    """Handle application-specific errors."""
    status_code = _get_status_code(exc)

    logger.warning(
        "app_error",
        error_type=type(exc).__name__,
        message=exc.message,
        code=exc.code,
        path=request.url.path,
    )

    return JSONResponse(
        status_code=status_code,
        content={
            "error": {
                "code": exc.code,
                "message": exc.message,
                "details": exc.details,
            }
        },
    )


def _get_status_code(exc: AppError) -> int:
    """Map exception types to HTTP status codes."""
    mapping = {
        NotFoundError: status.HTTP_404_NOT_FOUND,
        ConflictError: status.HTTP_409_CONFLICT,
        ValidationError: status.HTTP_422_UNPROCESSABLE_ENTITY,
        AuthenticationError: status.HTTP_401_UNAUTHORIZED,
        AuthorizationError: status.HTTP_403_FORBIDDEN,
        ExternalServiceError: status.HTTP_502_BAD_GATEWAY,
    }
    return mapping.get(type(exc), status.HTTP_500_INTERNAL_SERVER_ERROR)


async def unhandled_error_handler(request: Request, exc: Exception) -> JSONResponse:
    """Handle unexpected errors."""
    logger.exception(
        "unhandled_error",
        error_type=type(exc).__name__,
        path=request.url.path,
    )

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": {
                "code": "InternalServerError",
                "message": "An unexpected error occurred",
            }
        },
    )
```

```python
# src/main.py
from fastapi import FastAPI
from src.core.exceptions import AppError
from src.core.exception_handlers import app_error_handler, unhandled_error_handler

app = FastAPI()

# Register exception handlers
app.add_exception_handler(AppError, app_error_handler)
app.add_exception_handler(Exception, unhandled_error_handler)
```

## Error Response Schema

Define a consistent error response format:

```python
# src/schemas/common.py
from pydantic import BaseModel


class ErrorDetail(BaseModel):
    code: str
    message: str
    details: dict | None = None


class ErrorResponse(BaseModel):
    error: ErrorDetail


# Example response:
# {
#     "error": {
#         "code": "NotFoundError",
#         "message": "Product 123 not found",
#         "details": {"product_id": "123"}
#     }
# }
```

## Using Exceptions in Services

```python
# src/services/product_service.py
from src.core.exceptions import NotFoundError, ConflictError, ValidationError


class ProductService:
    async def get_by_id(self, product_id: UUID) -> Product:
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

    async def create(self, data: ProductCreate) -> Product:
        # Business validation
        if data.price < data.cost:
            raise ValidationError(
                message="Price cannot be less than cost",
                code="PriceBelowCost",
                details={"price": str(data.price), "cost": str(data.cost)},
            )

        # Uniqueness check
        existing = await self._get_by_sku(data.sku)
        if existing:
            raise ConflictError(
                message=f"Product with SKU {data.sku} already exists",
                code="DuplicateSKU",
                details={"sku": data.sku, "existing_id": str(existing.id)},
            )

        return await self._create(data)
```

## Pydantic Validation Errors

FastAPI automatically handles Pydantic validation errors with 422 responses:

```python
# Request body validation
class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    price: Decimal = Field(gt=0)

# Invalid request automatically returns:
# {
#     "detail": [
#         {
#             "type": "greater_than",
#             "loc": ["body", "price"],
#             "msg": "Input should be greater than 0",
#             "input": -10,
#             "ctx": {"gt": 0}
#         }
#     ]
# }
```

### Custom Validation Error Format

To customize the validation error format:

```python
# src/core/exception_handlers.py
from fastapi.exceptions import RequestValidationError

async def validation_error_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    """Custom format for validation errors."""
    errors = []
    for error in exc.errors():
        errors.append({
            "field": ".".join(str(loc) for loc in error["loc"][1:]),  # Skip "body"
            "message": error["msg"],
            "type": error["type"],
        })

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": {
                "code": "ValidationError",
                "message": "Request validation failed",
                "details": {"errors": errors},
            }
        },
    )

# Register in main.py
app.add_exception_handler(RequestValidationError, validation_error_handler)
```

## HTTP Exceptions

For simple cases, use FastAPI's `HTTPException` directly in routes:

```python
from fastapi import HTTPException, status

@router.get("/{product_id}")
async def get_product(product_id: UUID):
    product = await service.get_by_id(product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found",
        )
    return product
```

However, prefer domain exceptions in services for better separation of concerns.

## Error Handling Patterns

### Try/Except in Services

```python
class PaymentService:
    async def process_payment(self, order_id: UUID, amount: Decimal) -> Payment:
        try:
            result = await self.payment_gateway.charge(amount)
        except PaymentGatewayTimeout:
            raise ExternalServiceError(
                message="Payment gateway timed out",
                code="PaymentTimeout",
            )
        except PaymentDeclined as e:
            raise ValidationError(
                message="Payment was declined",
                code="PaymentDeclined",
                details={"reason": e.reason},
            )

        return Payment(order_id=order_id, amount=amount, transaction_id=result.id)
```

### Graceful Degradation

```python
class ProductService:
    async def get_with_recommendations(self, product_id: UUID) -> ProductWithRecs:
        product = await self.get_by_id(product_id)

        # Non-critical feature - degrade gracefully
        try:
            recommendations = await self.recommendation_service.get(product_id)
        except ExternalServiceError:
            logger.warning(
                "recommendations_unavailable",
                product_id=str(product_id),
            )
            recommendations = []

        return ProductWithRecs(product=product, recommendations=recommendations)
```

### Retries for External Services

```python
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
import httpx


class ExternalAPIService:
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=10),
        retry=retry_if_exception_type(httpx.TimeoutException),
    )
    async def fetch_data(self, resource_id: str) -> dict:
        response = await self.http_client.get(
            f"{self.base_url}/resources/{resource_id}",
            timeout=5.0,
        )
        response.raise_for_status()
        return response.json()
```

## Logging Errors

```python
import structlog

logger = structlog.get_logger()


class ProductService:
    async def create(self, data: ProductCreate) -> Product:
        try:
            product = await self._create(data)
            logger.info("product_created", product_id=str(product.id))
            return product
        except Exception as e:
            logger.exception(
                "product_creation_failed",
                sku=data.sku,
                error=str(e),
            )
            raise
```

## Comparison with .NET

| .NET Pattern | Python Equivalent |
|--------------|-------------------|
| `ExceptionFilterAttribute` | Exception handler functions |
| `ProblemDetails` | Custom error response schema |
| `IExceptionHandler` | `app.add_exception_handler()` |
| Middleware exception handling | Exception handlers + middleware |
| `FluentValidation` exceptions | Pydantic `ValidationError` |

## Best Practices

### 1. Use Domain Exceptions

```python
# Good - domain exception
raise NotFoundError(f"Product {product_id} not found")

# Avoid - generic exception
raise Exception("Product not found")

# Avoid - HTTP exception in service layer
raise HTTPException(404, "Not found")
```

### 2. Include Context in Errors

```python
# Good - includes helpful details
raise ConflictError(
    message=f"Product with SKU {data.sku} already exists",
    code="DuplicateSKU",
    details={"sku": data.sku, "existing_id": str(existing.id)},
)

# Avoid - vague error
raise ConflictError("Duplicate product")
```

### 3. Don't Expose Internal Details

```python
# Good - safe for clients
return JSONResponse(
    status_code=500,
    content={"error": {"code": "InternalError", "message": "An error occurred"}},
)

# Avoid - exposes stack trace
return JSONResponse(
    status_code=500,
    content={"error": str(exc), "traceback": traceback.format_exc()},
)
```

### 4. Log Before Re-raising

```python
# Good - log then raise
except ExternalAPIError as e:
    logger.error("external_api_failed", service="payment", error=str(e))
    raise ExternalServiceError("Payment service unavailable")

# Avoid - silently converting errors
except ExternalAPIError:
    raise ExternalServiceError("Payment service unavailable")  # Lost context
```

### 5. Use Specific Exception Types

```python
# Good - specific types
try:
    await self.payment_service.charge(amount)
except PaymentDeclined:
    # Handle declined payment
except PaymentTimeout:
    # Handle timeout differently

# Avoid - catching everything
try:
    await self.payment_service.charge(amount)
except Exception:
    # Can't distinguish error types
```
