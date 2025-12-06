# Logging & Tracing

## Overview

This guide covers structured logging with structlog and LLM tracing with Langfuse for FastAPI applications.

## structlog Setup

### Installation

```bash
uv add structlog
```

### Configuration

```python
# src/utils/logging.py
import logging
import sys
from typing import Any

import structlog
from structlog.types import Processor

from src.core.config import get_settings

settings = get_settings()


def setup_logging() -> None:
    """Configure structured logging for the application."""

    # Shared processors for all loggers
    shared_processors: list[Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.UnicodeDecoder(),
    ]

    if settings.environment == "development":
        # Development: pretty console output
        processors = shared_processors + [
            structlog.dev.ConsoleRenderer(colors=True),
        ]
    else:
        # Production: JSON output
        processors = shared_processors + [
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ]

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

    # Configure standard library logging
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=logging.INFO if not settings.debug else logging.DEBUG,
    )

    # Silence noisy loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(
        logging.INFO if settings.debug else logging.WARNING
    )
```

### Basic Usage

```python
import structlog

logger = structlog.get_logger()

# Simple logging
logger.info("Application started")
logger.warning("Cache miss", key="user:123")
logger.error("Database connection failed", host="db.example.com", port=5432)

# With context
logger.info(
    "product_created",
    product_id="abc-123",
    sku="WIDGET-001",
    price=29.99,
    created_by="user-456",
)

# Exception logging
try:
    risky_operation()
except Exception:
    logger.exception("Operation failed", operation="risky_operation")
```

## Request Context

### Correlation ID Middleware

```python
# src/core/middleware.py
import uuid
from contextvars import ContextVar
from typing import Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
import structlog

# Context variable for request-scoped data
correlation_id_var: ContextVar[str] = ContextVar("correlation_id", default="")
request_id_var: ContextVar[str] = ContextVar("request_id", default="")


class RequestContextMiddleware(BaseHTTPMiddleware):
    """Add correlation ID and request context to all requests."""

    async def dispatch(
        self,
        request: Request,
        call_next: Callable,
    ) -> Response:
        # Get or generate correlation ID
        correlation_id = request.headers.get("X-Correlation-ID", str(uuid.uuid4()))
        request_id = str(uuid.uuid4())

        # Set context variables
        correlation_id_var.set(correlation_id)
        request_id_var.set(request_id)

        # Bind to structlog context
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(
            correlation_id=correlation_id,
            request_id=request_id,
        )

        # Add to response headers
        response = await call_next(request)
        response.headers["X-Correlation-ID"] = correlation_id
        response.headers["X-Request-ID"] = request_id

        return response
```

### Request Logging Middleware

```python
# src/core/middleware.py
import time
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
import structlog

logger = structlog.get_logger()


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Log all HTTP requests with timing."""

    async def dispatch(self, request: Request, call_next) -> Response:
        start_time = time.perf_counter()

        # Log request start
        logger.info(
            "request_started",
            method=request.method,
            path=request.url.path,
            query=str(request.query_params),
            client_ip=request.client.host if request.client else None,
        )

        try:
            response = await call_next(request)
            duration_ms = (time.perf_counter() - start_time) * 1000

            # Log request completion
            logger.info(
                "request_completed",
                method=request.method,
                path=request.url.path,
                status_code=response.status_code,
                duration_ms=round(duration_ms, 2),
            )

            return response

        except Exception as e:
            duration_ms = (time.perf_counter() - start_time) * 1000
            logger.exception(
                "request_failed",
                method=request.method,
                path=request.url.path,
                duration_ms=round(duration_ms, 2),
                error=str(e),
            )
            raise
```

### Register Middleware

```python
# src/main.py
from fastapi import FastAPI
from src.core.middleware import RequestContextMiddleware, RequestLoggingMiddleware
from src.utils.logging import setup_logging

setup_logging()

app = FastAPI()

# Order matters: context first, then logging
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(RequestContextMiddleware)
```

## Logging in Services

```python
# src/services/product_service.py
import structlog

logger = structlog.get_logger()


class ProductService:
    async def create(self, data: ProductCreate, user_id: UUID) -> Product:
        logger.info(
            "creating_product",
            sku=data.sku,
            user_id=str(user_id),
        )

        product = Product(**data.model_dump(), created_by=user_id)
        self.db.add(product)
        await self.db.commit()
        await self.db.refresh(product)

        logger.info(
            "product_created",
            product_id=str(product.id),
            sku=product.sku,
        )

        return product

    async def delete(self, product_id: UUID) -> None:
        product = await self.get_by_id(product_id)

        logger.info(
            "deleting_product",
            product_id=str(product_id),
            sku=product.sku,
        )

        await self.db.delete(product)
        await self.db.commit()

        logger.info("product_deleted", product_id=str(product_id))
```

## Langfuse Integration

### Installation

```bash
uv add langfuse
```

### Configuration

```python
# src/core/config.py
class Settings(BaseSettings):
    langfuse_public_key: str | None = None
    langfuse_secret_key: SecretStr | None = None
    langfuse_host: str = "https://cloud.langfuse.com"
```

### Langfuse Client Setup

```python
# src/core/observability.py
from langfuse import Langfuse
from src.core.config import get_settings

settings = get_settings()

_langfuse: Langfuse | None = None


def get_langfuse() -> Langfuse | None:
    """Get Langfuse client singleton."""
    global _langfuse

    if not settings.langfuse_public_key or not settings.langfuse_secret_key:
        return None

    if _langfuse is None:
        _langfuse = Langfuse(
            public_key=settings.langfuse_public_key,
            secret_key=settings.langfuse_secret_key.get_secret_value(),
            host=settings.langfuse_host,
        )

    return _langfuse


async def shutdown_langfuse() -> None:
    """Flush and shutdown Langfuse client."""
    global _langfuse
    if _langfuse:
        _langfuse.flush()
        _langfuse = None
```

### Tracing LLM Calls

```python
# src/services/ai_service.py
from langfuse.decorators import observe, langfuse_context
import httpx
import structlog

logger = structlog.get_logger()


class AIService:
    def __init__(self, http_client: httpx.AsyncClient):
        self.client = http_client

    @observe(name="generate_summary")
    async def generate_summary(
        self,
        text: str,
        user_id: str | None = None,
    ) -> str:
        """Generate summary using LLM with Langfuse tracing."""
        # Set user context for Langfuse
        if user_id:
            langfuse_context.update_current_observation(user_id=user_id)

        logger.info("generating_summary", text_length=len(text))

        # Make LLM call
        response = await self.client.post(
            "https://api.openai.com/v1/chat/completions",
            json={
                "model": "gpt-4",
                "messages": [
                    {"role": "system", "content": "Summarize the following text."},
                    {"role": "user", "content": text},
                ],
            },
        )
        response.raise_for_status()
        result = response.json()

        summary = result["choices"][0]["message"]["content"]

        # Log token usage
        usage = result.get("usage", {})
        langfuse_context.update_current_observation(
            usage={
                "input": usage.get("prompt_tokens"),
                "output": usage.get("completion_tokens"),
            }
        )

        logger.info(
            "summary_generated",
            input_tokens=usage.get("prompt_tokens"),
            output_tokens=usage.get("completion_tokens"),
        )

        return summary

    @observe(name="classify_intent")
    async def classify_intent(self, query: str) -> str:
        """Classify user intent with nested spans."""
        # This creates a child span under the parent trace
        intent = await self._call_classifier(query)

        langfuse_context.update_current_observation(
            output=intent,
            metadata={"query_length": len(query)},
        )

        return intent
```

### Manual Tracing

```python
# src/services/workflow_service.py
from langfuse import Langfuse
from src.core.observability import get_langfuse


class WorkflowService:
    async def process_request(
        self,
        request_id: str,
        user_id: str,
        query: str,
    ) -> dict:
        """Process request with manual Langfuse tracing."""
        langfuse = get_langfuse()

        # Create root trace
        trace = langfuse.trace(
            name="process_request",
            user_id=user_id,
            session_id=request_id,
            input={"query": query},
        )

        try:
            # Step 1: Validate
            validation_span = trace.span(name="validate_input")
            is_valid = await self._validate(query)
            validation_span.end(output={"valid": is_valid})

            if not is_valid:
                trace.update(output={"error": "Invalid input"})
                return {"error": "Invalid input"}

            # Step 2: Generate (LLM call)
            generation = trace.generation(
                name="generate_response",
                model="gpt-4",
                input={"query": query},
            )

            response = await self._call_llm(query)

            generation.end(
                output=response["content"],
                usage={
                    "input": response["prompt_tokens"],
                    "output": response["completion_tokens"],
                },
            )

            # Step 3: Score
            trace.score(
                name="response_quality",
                value=0.9,  # Computed quality score
            )

            result = {"response": response["content"]}
            trace.update(output=result)

            return result

        except Exception as e:
            trace.update(
                output={"error": str(e)},
                level="ERROR",
            )
            raise
```

### Integrating with Middleware

```python
# src/core/middleware.py
from langfuse import Langfuse
from src.core.observability import get_langfuse


class LangfuseMiddleware(BaseHTTPMiddleware):
    """Add Langfuse trace context to requests."""

    async def dispatch(self, request: Request, call_next) -> Response:
        langfuse = get_langfuse()
        if not langfuse:
            return await call_next(request)

        # Get trace ID from header or create new
        trace_id = request.headers.get("X-Trace-ID")

        if trace_id:
            # Link to existing trace
            trace = langfuse.trace(id=trace_id, name="api_request")
        else:
            trace = langfuse.trace(
                name="api_request",
                input={
                    "method": request.method,
                    "path": request.url.path,
                },
            )

        # Store trace in request state
        request.state.langfuse_trace = trace

        try:
            response = await call_next(request)
            trace.update(
                output={"status_code": response.status_code},
                level="DEFAULT" if response.status_code < 400 else "ERROR",
            )
            return response
        except Exception as e:
            trace.update(output={"error": str(e)}, level="ERROR")
            raise
```

## Log Levels

| Level | Use Case |
|-------|----------|
| `DEBUG` | Detailed debugging info (not in production) |
| `INFO` | Normal operations, business events |
| `WARNING` | Unexpected but handled situations |
| `ERROR` | Errors that need attention |
| `CRITICAL` | System failures |

```python
logger.debug("SQL query executed", query=query, duration_ms=5.2)
logger.info("user_logged_in", user_id="123", provider="google")
logger.warning("rate_limit_approaching", current=95, limit=100)
logger.error("payment_failed", order_id="456", reason="card_declined")
logger.critical("database_unavailable", host="db.example.com")
```

## Comparison with .NET

| .NET (Serilog) | Python (structlog) |
|----------------|-------------------|
| `Log.Information()` | `logger.info()` |
| `Log.ForContext<T>()` | `structlog.get_logger(__name__)` |
| `LogContext.PushProperty()` | `structlog.contextvars.bind_contextvars()` |
| Enrichers | Processors |
| Sinks | Renderers |
| Destructuring `{@Object}` | Dict/object serialization |
| Correlation ID enricher | Context middleware |

## Best Practices

### 1. Use Structured Data

```python
# Good - structured data
logger.info(
    "order_created",
    order_id="123",
    total=99.99,
    items=3,
)

# Avoid - string interpolation
logger.info(f"Order 123 created with total $99.99 and 3 items")
```

### 2. Use Consistent Event Names

```python
# Good - snake_case, past tense for completed actions
logger.info("user_registered", ...)
logger.info("payment_processed", ...)
logger.info("email_sent", ...)

# Avoid - inconsistent naming
logger.info("UserRegistration", ...)
logger.info("processing payment", ...)
```

### 3. Include Context

```python
# Good - includes relevant context
logger.info(
    "product_updated",
    product_id=str(product.id),
    updated_fields=["name", "price"],
    updated_by=str(user.id),
)

# Avoid - missing context
logger.info("product_updated")
```

### 4. Don't Log Sensitive Data

```python
# Good - mask sensitive data
logger.info(
    "payment_processed",
    card_last_four="4242",
    amount=99.99,
)

# Avoid - exposing sensitive data
logger.info(
    "payment_processed",
    card_number="4242424242424242",  # Never!
    cvv="123",  # Never!
)
```

### 5. Use Appropriate Log Levels

```python
# Good - appropriate levels
logger.debug("cache_lookup", key="product:123")  # Detailed, dev only
logger.info("product_created", ...)  # Business event
logger.warning("retry_attempt", attempt=3, max=5)  # Concerning but handled
logger.error("external_api_failed", service="payment")  # Needs attention

# Avoid - wrong levels
logger.error("User clicked button")  # Not an error
logger.debug("Payment failed")  # Should be error
```
