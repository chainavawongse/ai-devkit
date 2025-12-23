# Alembic Migrations

## Overview

Alembic handles database schema migrations for SQLAlchemy, equivalent to EF Core Migrations in .NET.

## Setup

### Initialize Alembic

```bash
uv run alembic init migrations
```

### Configure Alembic

```python
# migrations/env.py
import asyncio
from logging.config import fileConfig
from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config
from alembic import context

from src.core.config import get_settings
from src.models.base import Base
# Import all models to register them with Base.metadata
from src.models import product, user, category  # noqa: F401

config = context.config
settings = get_settings()

# Set database URL from environment
config.set_main_option("sqlalchemy.url", str(settings.database_url))

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)

    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Run migrations in 'online' mode with async engine."""
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

```ini
# alembic.ini
[alembic]
script_location = migrations
prepend_sys_path = .
version_path_separator = os

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
```

## Common Commands

```bash
# Create a migration from model changes
uv run alembic revision --autogenerate -m "add products table"

# Run all pending migrations
uv run alembic upgrade head

# Run migrations up to a specific revision
uv run alembic upgrade <revision_id>

# Rollback one migration
uv run alembic downgrade -1

# Rollback to a specific revision
uv run alembic downgrade <revision_id>

# Rollback all migrations
uv run alembic downgrade base

# Show current revision
uv run alembic current

# Show migration history
uv run alembic history --verbose

# Show pending migrations
uv run alembic history --indicate-current

# Generate SQL without executing (for review)
uv run alembic upgrade head --sql
```

## Writing Migrations

### Auto-generated Migration

```python
# migrations/versions/2024_01_15_add_products_abc123.py
"""add products table

Revision ID: abc123
Revises: def456
Create Date: 2024-01-15 10:30:00.000000
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "abc123"
down_revision: Union[str, None] = "def456"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "products",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("sku", sa.String(length=50), nullable=False),
        sa.Column("price", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("category_id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["category_id"], ["categories.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("sku"),
    )
    op.create_index("ix_products_category_id", "products", ["category_id"])
    op.create_index("ix_products_created_at", "products", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_products_created_at", table_name="products")
    op.drop_index("ix_products_category_id", table_name="products")
    op.drop_table("products")
```

### Manual Migration

```python
"""add full text search to products

Revision ID: xyz789
Revises: abc123
Create Date: 2024-01-20 14:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision: str = "xyz789"
down_revision: str = "abc123"


def upgrade() -> None:
    # Add tsvector column
    op.add_column(
        "products",
        sa.Column("search_vector", sa.dialects.postgresql.TSVECTOR(), nullable=True),
    )

    # Create GIN index for full-text search
    op.create_index(
        "ix_products_search_vector",
        "products",
        ["search_vector"],
        postgresql_using="gin",
    )

    # Create trigger to update search vector
    op.execute("""
        CREATE OR REPLACE FUNCTION products_search_vector_update() RETURNS trigger AS $$
        BEGIN
            NEW.search_vector :=
                setweight(to_tsvector('english', COALESCE(NEW.name, '')), 'A') ||
                setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'B');
            RETURN NEW;
        END
        $$ LANGUAGE plpgsql;

        CREATE TRIGGER products_search_vector_trigger
        BEFORE INSERT OR UPDATE ON products
        FOR EACH ROW EXECUTE FUNCTION products_search_vector_update();
    """)

    # Backfill existing rows
    op.execute("""
        UPDATE products SET search_vector =
            setweight(to_tsvector('english', COALESCE(name, '')), 'A') ||
            setweight(to_tsvector('english', COALESCE(description, '')), 'B');
    """)


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS products_search_vector_trigger ON products")
    op.execute("DROP FUNCTION IF EXISTS products_search_vector_update()")
    op.drop_index("ix_products_search_vector", table_name="products")
    op.drop_column("products", "search_vector")
```

### Data Migration

```python
"""migrate user roles to permissions

Revision ID: mig001
Revises: xyz789
Create Date: 2024-02-01 09:00:00.000000
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.orm import Session

revision: str = "mig001"
down_revision: str = "xyz789"


# Define temporary table references for data migration
users = sa.table(
    "users",
    sa.column("id", sa.UUID),
    sa.column("role", sa.String),
)

permissions = sa.table(
    "permissions",
    sa.column("id", sa.UUID),
    sa.column("user_id", sa.UUID),
    sa.column("permission", sa.String),
)

ROLE_TO_PERMISSIONS = {
    "admin": ["read", "write", "delete", "admin"],
    "editor": ["read", "write"],
    "viewer": ["read"],
}


def upgrade() -> None:
    # Create permissions table
    op.create_table(
        "permissions",
        sa.Column("id", sa.UUID(), nullable=False, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("permission", sa.String(50), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    # Migrate data
    bind = op.get_bind()
    session = Session(bind=bind)

    # Read existing users
    result = session.execute(sa.select(users.c.id, users.c.role))

    # Create permission records
    for user_id, role in result:
        perms = ROLE_TO_PERMISSIONS.get(role, ["read"])
        for perm in perms:
            session.execute(
                permissions.insert().values(user_id=user_id, permission=perm)
            )

    session.commit()

    # Drop old role column
    op.drop_column("users", "role")


def downgrade() -> None:
    # Add role column back
    op.add_column("users", sa.Column("role", sa.String(50), nullable=True))

    # Migrate data back (simplified - use highest permission level)
    bind = op.get_bind()
    session = Session(bind=bind)

    # This is a simplified rollback - real rollback might need more logic
    op.execute("""
        UPDATE users SET role = 'viewer';
        UPDATE users SET role = 'editor'
        WHERE id IN (SELECT user_id FROM permissions WHERE permission = 'write');
        UPDATE users SET role = 'admin'
        WHERE id IN (SELECT user_id FROM permissions WHERE permission = 'admin');
    """)

    op.alter_column("users", "role", nullable=False, server_default="viewer")
    op.drop_table("permissions")
```

## PostgreSQL-Specific Operations

### Extensions

```python
def upgrade() -> None:
    # Enable extensions
    op.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"')
    op.execute('CREATE EXTENSION IF NOT EXISTS "vector"')  # pgvector
    op.execute('CREATE EXTENSION IF NOT EXISTS "postgis"')


def downgrade() -> None:
    # Usually don't drop extensions as other things may depend on them
    pass
```

### Enums

```python
from sqlalchemy.dialects import postgresql

# Create enum type
order_status = postgresql.ENUM(
    "pending", "confirmed", "shipped", "delivered", "cancelled",
    name="order_status",
)


def upgrade() -> None:
    order_status.create(op.get_bind())
    op.add_column("orders", sa.Column("status", order_status, nullable=False))


def downgrade() -> None:
    op.drop_column("orders", "status")
    order_status.drop(op.get_bind())
```

### Partial Indexes

```python
def upgrade() -> None:
    op.create_index(
        "ix_orders_pending",
        "orders",
        ["created_at"],
        postgresql_where=sa.text("status = 'pending'"),
    )
```

## Comparison with EF Core Migrations

| EF Core | Alembic |
|---------|---------|
| `Add-Migration` | `alembic revision --autogenerate -m` |
| `Update-Database` | `alembic upgrade head` |
| `Remove-Migration` | Delete file + `alembic downgrade -1` |
| `Script-Migration` | `alembic upgrade head --sql` |
| `__EFMigrationsHistory` | `alembic_version` table |
| `OnModelCreating` | Model definitions + autogenerate |
| `HasData()` seeding | Data migration in upgrade/downgrade |

## Best Practices

### 1. Review Auto-generated Migrations

```bash
# Always review before applying
uv run alembic revision --autogenerate -m "description"
# Open the file and verify the changes
uv run alembic upgrade head
```

### 2. Make Migrations Reversible

```python
def upgrade() -> None:
    op.add_column("users", sa.Column("phone", sa.String(20)))


def downgrade() -> None:
    op.drop_column("users", "phone")  # Always implement downgrade
```

### 3. Use Descriptive Names

```bash
# Good
uv run alembic revision --autogenerate -m "add_products_table"
uv run alembic revision --autogenerate -m "add_email_index_to_users"

# Avoid
uv run alembic revision --autogenerate -m "update"
uv run alembic revision --autogenerate -m "fix"
```

### 4. Handle Large Data Migrations

```python
def upgrade() -> None:
    # Batch large updates to avoid locking
    bind = op.get_bind()

    while True:
        result = bind.execute(sa.text("""
            UPDATE products
            SET new_column = compute_value(old_column)
            WHERE new_column IS NULL
            LIMIT 1000
        """))
        if result.rowcount == 0:
            break
```

### 5. Test Migrations

```bash
# Test full cycle
uv run alembic upgrade head
uv run alembic downgrade base
uv run alembic upgrade head
```

### 6. Squash Old Migrations

For long-running projects, periodically squash old migrations:

```bash
# 1. Ensure all environments are at head
# 2. Create a new baseline migration
uv run alembic revision --autogenerate -m "baseline_2024"
# 3. Delete old migration files
# 4. Update down_revision to None in baseline
```
