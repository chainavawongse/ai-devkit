# Python Backend Development Guide

## Quick Reference

**Stack**: FastAPI + Pydantic v2 + SQLAlchemy 2.0 (async) + PostgreSQL + pgvector

### Commands

```bash
# Package management (uv)
uv sync                          # Install dependencies
uv add <package>                 # Add dependency
uv add --dev <package>           # Add dev dependency
uv run <command>                 # Run command in venv

# Development
uv run uvicorn src.main:app --reload --port 8000

# Database
uv run alembic upgrade head      # Run migrations
uv run alembic revision --autogenerate -m "description"  # Create migration

# Testing
uv run pytest                    # All tests
uv run pytest tests/unit         # Unit tests only
uv run pytest tests/integration  # Integration tests only
uv run pytest -k "test_name"     # Run specific test
uv run pytest --cov=src          # With coverage

# Linting & Formatting
uv run ruff check .              # Lint
uv run ruff format .             # Format
uv run mypy src                  # Type checking
```

### Project Structure

```
src/
├── main.py                 # FastAPI app entry point
├── api/                    # Routers (endpoints)
│   ├── routes/
│   │   ├── __init__.py
│   │   ├── products.py
│   │   └── users.py
│   └── dependencies.py     # Shared Depends() functions
├── services/               # Business logic
│   ├── product_service.py
│   └── user_service.py
├── models/                 # SQLAlchemy models
│   ├── base.py
│   ├── product.py
│   └── user.py
├── schemas/                # Pydantic DTOs
│   ├── product.py
│   └── user.py
├── core/                   # App configuration
│   ├── config.py           # Settings (pydantic-settings)
│   ├── database.py         # DB session management
│   ├── security.py         # Auth utilities
│   └── exceptions.py       # Custom exceptions
└── utils/                  # Shared utilities
    └── logging.py          # structlog setup
tests/
├── conftest.py             # Shared fixtures
├── unit/                   # Unit tests (mocked DB)
└── integration/            # Integration tests (real DB)
migrations/                 # Alembic migrations
├── versions/
└── env.py
pyproject.toml              # Project config & dependencies
```

## Documentation Index

### Architecture

| Document | Description |
|----------|-------------|
| [Project Structure](api/architecture/project-structure.md) | Folder layout, layer responsibilities |
| [Dependency Injection](api/architecture/dependency-injection.md) | FastAPI `Depends()`, service injection |

### Patterns

| Document | When to Read |
|----------|--------------|
| [Router Patterns](api/patterns/router-patterns.md) | Creating API endpoints |
| [Service Patterns](api/patterns/service-patterns.md) | Business logic implementation |
| [Error Handling](api/patterns/error-handling.md) | Exceptions, HTTP errors |
| [Async Patterns](api/patterns/async-patterns.md) | async/await best practices |
| [Pydantic Patterns](api/patterns/pydantic-patterns.md) | Schemas, validation, settings |

### Data Layer

| Document | When to Read |
|----------|--------------|
| [SQLAlchemy](api/data/sqlalchemy.md) | Models, async sessions, queries |
| [Alembic](api/data/alembic.md) | Database migrations |
| [pgvector](api/data/pgvector.md) | Vector embeddings, similarity search |

### Security

| Document | When to Read |
|----------|--------------|
| [Authentication](api/security/authentication.md) | JWT, OAuth providers |
| [Authorization](api/security/authorization.md) | Permission checks, guards |

### Observability

| Document | When to Read |
|----------|--------------|
| [Logging & Tracing](api/observability/logging-tracing.md) | structlog, Langfuse |

### Standards

| Document | When to Read |
|----------|--------------|
| [Naming Conventions](api/standards/naming-conventions.md) | File, class, function naming |

### Testing

| Document | When to Read |
|----------|--------------|
| [Unit Testing](api/testing/unit-testing.md) | pytest, mocking patterns |
| [Integration Testing](api/testing/integration-testing.md) | Real DB, test fixtures |

### Examples

| Template | Purpose |
|----------|---------|
| [router_template.py](api/examples/router_template.py) | FastAPI router with CRUD |
| [service_template.py](api/examples/service_template.py) | Service class pattern |
| [schema_template.py](api/examples/schema_template.py) | Pydantic schemas |
| [model_template.py](api/examples/model_template.py) | SQLAlchemy model |
| [unit_test_template.py](api/examples/test_templates/unit_test_template.py) | Unit test patterns |
| [integration_test_template.py](api/examples/test_templates/integration_test_template.py) | Integration test patterns |

## Key Principles

### 1. Async Everywhere

All I/O operations should be async:

```python
# Database queries
async def get_user(db: AsyncSession, user_id: UUID) -> User | None:
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()

# HTTP calls
async with httpx.AsyncClient() as client:
    response = await client.get(url)
```

### 2. Pydantic for All Boundaries

Every data boundary uses Pydantic:

```python
# API input/output
class CreateProductRequest(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    price: Decimal = Field(gt=0)

# Configuration
class Settings(BaseSettings):
    database_url: PostgresDsn
    jwt_secret: SecretStr
```

### 3. Type Hints Always

Full type hints with `mypy --strict` compatibility:

```python
async def create_product(
    db: AsyncSession,
    data: CreateProductRequest,
    user_id: UUID,
) -> ProductResponse:
    ...
```

### 4. Structured Logging

Use structlog with context:

```python
logger = structlog.get_logger()

logger.info("product_created", product_id=str(product.id), user_id=str(user_id))
```

## Common Tasks

### Adding a New Endpoint

1. Create/update schema in `src/schemas/`
2. Create/update service in `src/services/`
3. Add route in `src/api/routes/`
4. Register router in `src/main.py`
5. Add tests in `tests/unit/` and `tests/integration/`

### Adding a New Model

1. Create model in `src/models/`
2. Import in `src/models/__init__.py`
3. Create migration: `uv run alembic revision --autogenerate -m "add_model"`
4. Run migration: `uv run alembic upgrade head`

### Environment Variables

Required variables:

```bash
# Database
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/dbname

# Security
JWT_SECRET_KEY=your-secret-key
JWT_ALGORITHM=HS256

# OAuth (optional)
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...

# Observability
LANGFUSE_PUBLIC_KEY=...
LANGFUSE_SECRET_KEY=...
LANGFUSE_HOST=https://cloud.langfuse.com
```
