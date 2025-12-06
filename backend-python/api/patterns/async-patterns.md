# Async Patterns

## Overview

Python's `async`/`await` syntax enables non-blocking I/O operations. FastAPI is built on async foundations, making it essential to understand these patterns.

## When to Use Async

| Operation | Use Async? | Reason |
|-----------|------------|--------|
| Database queries | Yes | I/O bound |
| HTTP requests | Yes | I/O bound |
| File I/O | Yes | I/O bound |
| CPU-intensive work | No | Use `run_in_executor` |
| Simple data transforms | No | Sync is fine |

## Basic Patterns

### Async Function

```python
async def get_user(user_id: UUID) -> User:
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()
```

### Calling Async Functions

```python
# In another async function
async def get_user_profile(user_id: UUID) -> UserProfile:
    user = await get_user(user_id)  # Must await
    return UserProfile.from_user(user)

# In FastAPI route (already async context)
@router.get("/users/{user_id}")
async def get_user_endpoint(user_id: UUID):
    return await get_user(user_id)
```

## Concurrent Execution

### asyncio.gather - Parallel Execution

Run multiple operations concurrently:

```python
import asyncio


async def get_dashboard_data(user_id: UUID) -> DashboardData:
    """Fetch multiple resources in parallel."""
    # All three queries run concurrently
    user, orders, notifications = await asyncio.gather(
        get_user(user_id),
        get_recent_orders(user_id),
        get_notifications(user_id),
    )

    return DashboardData(
        user=user,
        orders=orders,
        notifications=notifications,
    )
```

### Error Handling with gather

```python
async def get_dashboard_data(user_id: UUID) -> DashboardData:
    """Handle errors from concurrent operations."""
    results = await asyncio.gather(
        get_user(user_id),
        get_recent_orders(user_id),
        get_notifications(user_id),
        return_exceptions=True,  # Don't raise, return exceptions
    )

    user, orders, notifications = results

    # Handle individual failures
    if isinstance(orders, Exception):
        logger.warning("orders_fetch_failed", error=str(orders))
        orders = []

    if isinstance(notifications, Exception):
        logger.warning("notifications_fetch_failed", error=str(notifications))
        notifications = []

    return DashboardData(user=user, orders=orders, notifications=notifications)
```

### asyncio.TaskGroup (Python 3.11+)

Structured concurrency with automatic cancellation:

```python
async def process_batch(items: list[Item]) -> list[Result]:
    """Process items concurrently with TaskGroup."""
    results = []

    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(process_item(item)) for item in items]

    # All tasks completed successfully (or TaskGroup raised)
    results = [task.result() for task in tasks]
    return results
```

### Semaphore - Limiting Concurrency

Prevent overwhelming resources:

```python
async def fetch_all_products(product_ids: list[UUID]) -> list[Product]:
    """Fetch products with limited concurrency."""
    semaphore = asyncio.Semaphore(10)  # Max 10 concurrent requests

    async def fetch_with_limit(product_id: UUID) -> Product:
        async with semaphore:
            return await external_api.get_product(product_id)

    return await asyncio.gather(*[fetch_with_limit(id) for id in product_ids])
```

## Database Patterns

### Async Session

```python
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

async_session_factory = async_sessionmaker(engine, class_=AsyncSession)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        yield session
```

### Executing Queries

```python
from sqlalchemy import select

async def get_products(db: AsyncSession, category: str) -> list[Product]:
    result = await db.execute(
        select(Product).where(Product.category == category)
    )
    return list(result.scalars().all())
```

### Streaming Large Results

```python
async def stream_all_products(db: AsyncSession):
    """Stream products without loading all into memory."""
    result = await db.stream(select(Product))
    async for product in result.scalars():
        yield product


# Usage
async for product in stream_all_products(db):
    await process_product(product)
```

### Bulk Operations

```python
async def bulk_create_products(
    db: AsyncSession,
    products_data: list[ProductCreate],
) -> list[Product]:
    """Efficiently create multiple products."""
    products = [Product(**data.model_dump()) for data in products_data]
    db.add_all(products)
    await db.commit()

    # Refresh all to get generated IDs
    for product in products:
        await db.refresh(product)

    return products
```

## HTTP Client Patterns

### httpx Async Client

```python
import httpx


class ExternalAPIClient:
    def __init__(self):
        self.client = httpx.AsyncClient(
            base_url="https://api.example.com",
            timeout=30.0,
            headers={"Authorization": f"Bearer {API_KEY}"},
        )

    async def get_resource(self, resource_id: str) -> dict:
        response = await self.client.get(f"/resources/{resource_id}")
        response.raise_for_status()
        return response.json()

    async def close(self):
        await self.client.aclose()
```

### Reusing HTTP Client

```python
# src/core/http.py
import httpx
from contextlib import asynccontextmanager


_client: httpx.AsyncClient | None = None


async def get_http_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(timeout=30.0)
    return _client


async def close_http_client():
    global _client
    if _client:
        await _client.aclose()
        _client = None


# src/main.py
@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await close_http_client()
```

### Retries with Exponential Backoff

```python
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential,
    retry_if_exception_type,
)


class ExternalAPIClient:
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=10),
        retry=retry_if_exception_type((httpx.TimeoutException, httpx.ConnectError)),
    )
    async def get_resource(self, resource_id: str) -> dict:
        response = await self.client.get(f"/resources/{resource_id}")
        response.raise_for_status()
        return response.json()
```

## Context Managers

### Async Context Manager

```python
from contextlib import asynccontextmanager


@asynccontextmanager
async def timed_operation(name: str):
    """Log operation duration."""
    start = time.monotonic()
    try:
        yield
    finally:
        duration = time.monotonic() - start
        logger.info(f"{name}_completed", duration_ms=duration * 1000)


# Usage
async def process_order(order_id: UUID):
    async with timed_operation("process_order"):
        await do_processing(order_id)
```

### Resource Cleanup

```python
class DatabasePool:
    async def __aenter__(self) -> "DatabasePool":
        self.engine = create_async_engine(DATABASE_URL)
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.engine.dispose()


# Usage
async with DatabasePool() as pool:
    async with pool.get_session() as session:
        await session.execute(...)
```

## Background Tasks

### FastAPI Background Tasks

```python
from fastapi import BackgroundTasks


async def send_email(to: str, subject: str, body: str):
    """Background task for sending email."""
    async with httpx.AsyncClient() as client:
        await client.post(
            "https://api.email.com/send",
            json={"to": to, "subject": subject, "body": body},
        )


@router.post("/orders")
async def create_order(
    data: OrderCreate,
    background_tasks: BackgroundTasks,
):
    order = await order_service.create(data)

    # Schedule email without blocking response
    background_tasks.add_task(
        send_email,
        to=order.customer_email,
        subject="Order Confirmation",
        body=f"Your order {order.id} has been placed.",
    )

    return order
```

### Long-Running Tasks

For tasks that outlive the request, use a task queue (not covered here since you're skipping RabbitMQ/FastStream docs).

## CPU-Bound Work

### run_in_executor

For CPU-intensive operations, offload to a thread pool:

```python
import asyncio
from concurrent.futures import ThreadPoolExecutor

executor = ThreadPoolExecutor(max_workers=4)


def cpu_intensive_sync(data: bytes) -> bytes:
    """CPU-bound operation (sync)."""
    # Heavy computation...
    return processed_data


async def process_data(data: bytes) -> bytes:
    """Run CPU-bound work without blocking event loop."""
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(executor, cpu_intensive_sync, data)
```

## Timeouts

### asyncio.timeout (Python 3.11+)

```python
async def fetch_with_timeout(url: str) -> dict:
    """Fetch with explicit timeout."""
    async with asyncio.timeout(5.0):  # 5 second timeout
        async with httpx.AsyncClient() as client:
            response = await client.get(url)
            return response.json()
```

### asyncio.wait_for (older Python)

```python
async def fetch_with_timeout(url: str) -> dict:
    """Fetch with timeout (pre-3.11)."""
    try:
        return await asyncio.wait_for(fetch_url(url), timeout=5.0)
    except asyncio.TimeoutError:
        raise ExternalServiceError("Request timed out")
```

## Common Pitfalls

### 1. Forgetting to await

```python
# Bug - coroutine not awaited
async def bad_example():
    get_user(user_id)  # Returns coroutine, doesn't execute!
    return "done"

# Correct
async def good_example():
    await get_user(user_id)
    return "done"
```

### 2. Blocking the Event Loop

```python
# Bad - blocks event loop
async def bad_example():
    time.sleep(5)  # Blocks!
    data = requests.get(url)  # Blocks!

# Good - non-blocking
async def good_example():
    await asyncio.sleep(5)
    async with httpx.AsyncClient() as client:
        data = await client.get(url)
```

### 3. Creating Too Many Concurrent Tasks

```python
# Bad - may overwhelm database
async def bad_example(ids: list[UUID]):
    return await asyncio.gather(*[get_item(id) for id in ids])  # 10000 concurrent!

# Good - limit concurrency
async def good_example(ids: list[UUID]):
    semaphore = asyncio.Semaphore(50)

    async def limited_get(id: UUID):
        async with semaphore:
            return await get_item(id)

    return await asyncio.gather(*[limited_get(id) for id in ids])
```

### 4. Not Closing Resources

```python
# Bad - client never closed
client = httpx.AsyncClient()
response = await client.get(url)

# Good - proper cleanup
async with httpx.AsyncClient() as client:
    response = await client.get(url)
```

## Comparison with .NET

| .NET | Python |
|------|--------|
| `async Task<T>` | `async def -> T` |
| `await` | `await` |
| `Task.WhenAll()` | `asyncio.gather()` |
| `Task.Run()` | `loop.run_in_executor()` |
| `SemaphoreSlim` | `asyncio.Semaphore` |
| `CancellationToken` | `asyncio.TaskGroup` + exceptions |
| `IAsyncEnumerable` | `async for` + async generators |

## Best Practices

1. **Use async for all I/O**: Database, HTTP, file operations
2. **Reuse clients**: Create once, reuse throughout application lifetime
3. **Limit concurrency**: Use semaphores when making many parallel requests
4. **Handle timeouts**: Always set timeouts for external calls
5. **Clean up resources**: Use async context managers
6. **Don't block**: Never use `time.sleep()` or sync HTTP libraries in async code
