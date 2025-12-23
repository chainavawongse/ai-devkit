# Dependency Injection

## Overview

FastAPI's dependency injection uses the `Depends()` function to declare dependencies in route handlers. Unlike .NET's constructor injection with a DI container, Python relies on function-based factories.

## Comparison with .NET

| .NET Pattern | Python/FastAPI Equivalent |
|--------------|---------------------------|
| `services.AddScoped<IService, Service>()` | `Depends(get_service)` |
| Constructor injection | Function parameter with `Depends()` |
| `IServiceProvider` | No equivalent; use closures |
| Keyed services | Multiple dependency functions |

## Basic Patterns

### Simple Dependency

```python
# src/api/dependencies.py
from src.core.config import Settings

def get_settings() -> Settings:
    """Settings are loaded once and cached."""
    return Settings()

# Usage in route
@router.get("/config")
async def get_config(settings: Settings = Depends(get_settings)):
    return {"app_name": settings.app_name}
```

### Database Session

```python
# src/core/database.py
from collections.abc import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from src.core.config import Settings

settings = Settings()

engine = create_async_engine(
    str(settings.database_url),
    echo=settings.debug,
    pool_size=5,
    max_overflow=10,
)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Yield a database session, ensuring cleanup."""
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise

# Usage in route
@router.get("/products/{product_id}")
async def get_product(
    product_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Product).where(Product.id == product_id))
    return result.scalar_one_or_none()
```

### Service Injection

```python
# src/api/dependencies.py
from sqlalchemy.ext.asyncio import AsyncSession
from src.core.database import get_db
from src.services.product_service import ProductService

def get_product_service(
    db: AsyncSession = Depends(get_db),
) -> ProductService:
    """Factory for ProductService with database session."""
    return ProductService(db)

# Usage in route
@router.post("/products")
async def create_product(
    data: ProductCreate,
    service: ProductService = Depends(get_product_service),
) -> ProductResponse:
    return await service.create(data)
```

### Chained Dependencies

Dependencies can depend on other dependencies:

```python
# src/api/dependencies.py
from src.services.auth_service import AuthService
from src.services.user_service import UserService

def get_auth_service(
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> AuthService:
    return AuthService(db, settings.jwt_secret_key)

def get_user_service(
    db: AsyncSession = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
) -> UserService:
    return UserService(db, auth_service)
```

## Authentication Dependencies

### Current User

```python
# src/api/dependencies.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from src.models.user import User
from src.core.security import decode_jwt

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Extract and validate user from JWT token."""
    token = credentials.credentials
    try:
        payload = decode_jwt(token)
        user_id = UUID(payload["sub"])
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
        )

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    return user

# Usage - protected route
@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)):
    return current_user
```

### Optional Authentication

```python
async def get_current_user_optional(
    credentials: HTTPAuthorizationCredentials | None = Depends(
        HTTPBearer(auto_error=False)
    ),
    db: AsyncSession = Depends(get_db),
) -> User | None:
    """Return user if authenticated, None otherwise."""
    if not credentials:
        return None
    # ... same logic as get_current_user
```

### Role-Based Access

```python
from functools import wraps
from typing import Callable

def require_roles(*roles: str) -> Callable:
    """Dependency factory for role-based access control."""
    async def role_checker(
        current_user: User = Depends(get_current_user),
    ) -> User:
        if current_user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )
        return current_user
    return role_checker

# Usage
@router.delete("/products/{product_id}")
async def delete_product(
    product_id: UUID,
    current_user: User = Depends(require_roles("admin", "manager")),
    service: ProductService = Depends(get_product_service),
):
    await service.delete(product_id)
```

## AppState Pattern

For complex applications with many shared services, use an AppState singleton (similar to your ai-services architecture):

```python
# src/core/app_state.py
from dataclasses import dataclass, field
from typing import TYPE_CHECKING
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker
import httpx
import structlog

if TYPE_CHECKING:
    from langfuse import Langfuse

@dataclass
class AppState:
    """Application-wide state with lazy-loaded services."""

    _engine: AsyncEngine | None = field(default=None, repr=False)
    _session_factory: async_sessionmaker[AsyncSession] | None = field(default=None, repr=False)
    _http_client: httpx.AsyncClient | None = field(default=None, repr=False)
    _langfuse: "Langfuse | None" = field(default=None, repr=False)

    @property
    def engine(self) -> AsyncEngine:
        if self._engine is None:
            from src.core.database import create_engine
            self._engine = create_engine()
        return self._engine

    @property
    def session_factory(self) -> async_sessionmaker[AsyncSession]:
        if self._session_factory is None:
            self._session_factory = async_sessionmaker(
                self.engine,
                class_=AsyncSession,
                expire_on_commit=False,
            )
        return self._session_factory

    @property
    def http_client(self) -> httpx.AsyncClient:
        if self._http_client is None:
            self._http_client = httpx.AsyncClient(timeout=30.0)
        return self._http_client

    @property
    def langfuse(self) -> "Langfuse":
        if self._langfuse is None:
            from langfuse import Langfuse
            self._langfuse = Langfuse()
        return self._langfuse

    async def close(self) -> None:
        """Cleanup all resources."""
        if self._http_client:
            await self._http_client.aclose()
        if self._engine:
            await self._engine.dispose()


# Global singleton
_app_state: AppState | None = None

def get_app_state() -> AppState:
    global _app_state
    if _app_state is None:
        _app_state = AppState()
    return _app_state
```

```python
# src/main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI
from src.core.app_state import get_app_state

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    app_state = get_app_state()
    yield
    # Shutdown
    await app_state.close()

app = FastAPI(lifespan=lifespan)
```

```python
# src/api/dependencies.py
from src.core.app_state import get_app_state, AppState

def get_db_from_state(
    app_state: AppState = Depends(get_app_state),
) -> AsyncGenerator[AsyncSession, None]:
    async with app_state.session_factory() as session:
        yield session
```

## Testing with Dependencies

### Override Dependencies

```python
# tests/conftest.py
import pytest
from fastapi.testclient import TestClient
from src.main import app
from src.api.dependencies import get_db, get_current_user

@pytest.fixture
def mock_db():
    """Mock database session."""
    return AsyncMock(spec=AsyncSession)

@pytest.fixture
def mock_user():
    """Mock authenticated user."""
    return User(id=uuid4(), email="test@example.com", role="user")

@pytest.fixture
def client(mock_db, mock_user):
    """Test client with overridden dependencies."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: mock_user
    yield TestClient(app)
    app.dependency_overrides.clear()
```

### Per-Test Overrides

```python
def test_admin_only_endpoint(client, mock_user):
    # Override for this specific test
    mock_user.role = "admin"
    app.dependency_overrides[get_current_user] = lambda: mock_user

    response = client.delete("/products/123")
    assert response.status_code == 200
```

## Best Practices

### 1. Keep Dependencies Simple

```python
# Good - single responsibility
def get_product_service(db: AsyncSession = Depends(get_db)) -> ProductService:
    return ProductService(db)

# Avoid - too many responsibilities
def get_everything(
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(get_settings),
    http_client: httpx.AsyncClient = Depends(get_http_client),
    cache: Redis = Depends(get_cache),
) -> dict:  # Returning a dict of services is an anti-pattern
    ...
```

### 2. Use Type Hints

```python
# Good - explicit return type
def get_product_service(db: AsyncSession = Depends(get_db)) -> ProductService:
    return ProductService(db)

# Avoid - no return type
def get_product_service(db = Depends(get_db)):
    return ProductService(db)
```

### 3. Handle Cleanup with Generators

```python
# Good - cleanup guaranteed
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        yield session

# Avoid - no cleanup on exceptions
async def get_db() -> AsyncSession:
    session = async_session_factory()
    return session  # Session never closed!
```

### 4. Organize Dependencies

```python
# src/api/dependencies.py
"""
Dependency factories organized by concern.
"""

# ============================================================
# Database
# ============================================================

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    ...

# ============================================================
# Authentication
# ============================================================

async def get_current_user(...) -> User:
    ...

async def get_current_user_optional(...) -> User | None:
    ...

# ============================================================
# Services
# ============================================================

def get_product_service(...) -> ProductService:
    ...

def get_user_service(...) -> UserService:
    ...
```

### 5. Avoid Circular Imports

```python
# If services import each other, use TYPE_CHECKING
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from src.services.email_service import EmailService

class UserService:
    def __init__(
        self,
        db: AsyncSession,
        email_service: "EmailService",  # Forward reference
    ):
        ...
```
