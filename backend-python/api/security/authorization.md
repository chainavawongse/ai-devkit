# Authorization

## Overview

This guide covers permission-based authorization patterns for FastAPI applications, equivalent to ASP.NET Core's policy-based authorization.

## Role-Based Access Control (RBAC)

### User Model with Role

```python
# src/models/user.py
from enum import Enum
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from src.models.base import Base, UUIDPrimaryKeyMixin


class UserRole(str, Enum):
    ADMIN = "admin"
    MANAGER = "manager"
    USER = "user"
    VIEWER = "viewer"


class User(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(255), unique=True)
    name: Mapped[str] = mapped_column(String(100))
    role: Mapped[UserRole] = mapped_column(default=UserRole.USER)
    is_active: Mapped[bool] = mapped_column(default=True)
```

### Role-Based Dependency

```python
# src/api/dependencies.py
from fastapi import Depends, HTTPException, status
from src.models.user import User, UserRole


def require_role(*roles: UserRole):
    """Dependency factory for role-based access control."""

    async def role_checker(
        current_user: User = Depends(get_current_user),
    ) -> User:
        if current_user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Role {current_user.role} not authorized for this action",
            )
        return current_user

    return role_checker


# Usage in routes
@router.delete("/{product_id}")
async def delete_product(
    product_id: UUID,
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.MANAGER)),
):
    """Only admins and managers can delete products."""
    ...


@router.get("/admin/dashboard")
async def admin_dashboard(
    current_user: User = Depends(require_role(UserRole.ADMIN)),
):
    """Admin-only endpoint."""
    ...
```

## Permission-Based Access Control

### Permission Model

```python
# src/models/permission.py
from uuid import UUID
from sqlalchemy import String, ForeignKey, Table, Column
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.models.base import Base, UUIDPrimaryKeyMixin


# Many-to-many: users <-> permissions
user_permissions = Table(
    "user_permissions",
    Base.metadata,
    Column("user_id", ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
    Column("permission_id", ForeignKey("permissions.id", ondelete="CASCADE"), primary_key=True),
)


class Permission(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "permissions"

    name: Mapped[str] = mapped_column(String(100), unique=True)
    description: Mapped[str | None] = mapped_column(String(500))

    users: Mapped[list["User"]] = relationship(
        secondary=user_permissions,
        back_populates="permissions",
    )


class User(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(255), unique=True)
    permissions: Mapped[list["Permission"]] = relationship(
        secondary=user_permissions,
        back_populates="users",
        lazy="selectin",  # Eager load permissions
    )

    def has_permission(self, permission_name: str) -> bool:
        """Check if user has a specific permission."""
        return any(p.name == permission_name for p in self.permissions)

    def has_any_permission(self, *permission_names: str) -> bool:
        """Check if user has any of the specified permissions."""
        user_perms = {p.name for p in self.permissions}
        return bool(user_perms & set(permission_names))

    def has_all_permissions(self, *permission_names: str) -> bool:
        """Check if user has all specified permissions."""
        user_perms = {p.name for p in self.permissions}
        return set(permission_names).issubset(user_perms)
```

### Permission Constants

```python
# src/core/permissions.py
class Permissions:
    """Permission constants."""

    # Products
    PRODUCTS_READ = "products:read"
    PRODUCTS_CREATE = "products:create"
    PRODUCTS_UPDATE = "products:update"
    PRODUCTS_DELETE = "products:delete"

    # Users
    USERS_READ = "users:read"
    USERS_CREATE = "users:create"
    USERS_UPDATE = "users:update"
    USERS_DELETE = "users:delete"

    # Admin
    ADMIN_ACCESS = "admin:access"
    ADMIN_SETTINGS = "admin:settings"

    # Reports
    REPORTS_VIEW = "reports:view"
    REPORTS_EXPORT = "reports:export"
```

### Permission-Based Dependency

```python
# src/api/dependencies.py
from src.core.permissions import Permissions


def require_permission(*permissions: str):
    """Dependency factory for permission-based access control."""

    async def permission_checker(
        current_user: User = Depends(get_current_user),
    ) -> User:
        if not current_user.has_any_permission(*permissions):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )
        return current_user

    return permission_checker


def require_all_permissions(*permissions: str):
    """Require ALL specified permissions."""

    async def permission_checker(
        current_user: User = Depends(get_current_user),
    ) -> User:
        if not current_user.has_all_permissions(*permissions):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )
        return current_user

    return permission_checker


# Usage
@router.post("/products")
async def create_product(
    data: ProductCreate,
    current_user: User = Depends(require_permission(Permissions.PRODUCTS_CREATE)),
):
    ...


@router.get("/reports/export")
async def export_reports(
    current_user: User = Depends(
        require_all_permissions(Permissions.REPORTS_VIEW, Permissions.REPORTS_EXPORT)
    ),
):
    ...
```

## Resource-Based Authorization

### Owner Check

```python
# src/api/dependencies.py
from uuid import UUID


class ResourceOwnerChecker:
    """Check if user owns a resource."""

    def __init__(self, get_resource_owner_id):
        self.get_resource_owner_id = get_resource_owner_id

    async def __call__(
        self,
        resource_id: UUID,
        current_user: User = Depends(get_current_user),
        db: AsyncSession = Depends(get_db),
    ) -> User:
        owner_id = await self.get_resource_owner_id(db, resource_id)

        if owner_id != current_user.id:
            # Allow admins to bypass
            if not current_user.has_permission(Permissions.ADMIN_ACCESS):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Not authorized to access this resource",
                )

        return current_user


# Usage
async def get_product_owner_id(db: AsyncSession, product_id: UUID) -> UUID:
    result = await db.execute(
        select(Product.created_by).where(Product.id == product_id)
    )
    row = result.one_or_none()
    if not row:
        raise HTTPException(404, "Product not found")
    return row[0]


require_product_owner = ResourceOwnerChecker(get_product_owner_id)


@router.patch("/{product_id}")
async def update_product(
    product_id: UUID,
    data: ProductUpdate,
    current_user: User = Depends(require_product_owner),
):
    """Only product owner or admin can update."""
    ...
```

### Service-Level Authorization

```python
# src/services/product_service.py
from src.core.exceptions import AuthorizationError


class ProductService:
    async def update(
        self,
        product_id: UUID,
        data: ProductUpdate,
        user: User,
    ) -> Product:
        product = await self.get_by_id(product_id)

        # Check ownership or admin permission
        if product.created_by != user.id:
            if not user.has_permission(Permissions.ADMIN_ACCESS):
                raise AuthorizationError("Not authorized to update this product")

        # Apply updates
        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(product, field, value)

        await self.db.commit()
        return product

    async def delete(
        self,
        product_id: UUID,
        user: User,
    ) -> None:
        product = await self.get_by_id(product_id)

        # Require explicit delete permission
        if not user.has_permission(Permissions.PRODUCTS_DELETE):
            raise AuthorizationError("Delete permission required")

        # Also check ownership for non-admins
        if product.created_by != user.id:
            if not user.has_permission(Permissions.ADMIN_ACCESS):
                raise AuthorizationError("Not authorized to delete this product")

        await self.db.delete(product)
        await self.db.commit()
```

## Router-Level Authorization

### Protected Router

```python
# src/api/routes/admin.py
from fastapi import APIRouter, Depends
from src.api.dependencies import require_permission
from src.core.permissions import Permissions

# All routes in this router require admin access
router = APIRouter(
    prefix="/admin",
    tags=["admin"],
    dependencies=[Depends(require_permission(Permissions.ADMIN_ACCESS))],
)


@router.get("/users")
async def list_all_users():
    """Already protected by router-level dependency."""
    ...


@router.get("/settings")
async def get_settings(
    # Additional permission check
    current_user: User = Depends(require_permission(Permissions.ADMIN_SETTINGS)),
):
    """Requires both admin:access AND admin:settings."""
    ...
```

## Combining Authentication Methods

```python
# src/api/dependencies.py
from fastapi import Depends, HTTPException, Security
from fastapi.security import HTTPBearer, APIKeyHeader

http_bearer = HTTPBearer(auto_error=False)
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


async def get_current_principal(
    bearer_credentials: HTTPAuthorizationCredentials | None = Security(http_bearer),
    api_key: str | None = Security(api_key_header),
    db: AsyncSession = Depends(get_db),
) -> User | APIKey:
    """Authenticate via JWT or API key."""
    if bearer_credentials:
        # JWT authentication
        return await get_current_user(bearer_credentials, db)
    elif api_key:
        # API key authentication
        return await get_api_key(api_key, db)
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )


def require_permission_for_principal(*permissions: str):
    """Check permissions for either User or APIKey."""

    async def checker(
        principal: User | APIKey = Depends(get_current_principal),
    ) -> User | APIKey:
        if isinstance(principal, User):
            if not principal.has_any_permission(*permissions):
                raise HTTPException(403, "Insufficient permissions")
        elif isinstance(principal, APIKey):
            if not principal.has_scope(*permissions):
                raise HTTPException(403, "API key lacks required scope")
        return principal

    return checker
```

## Testing Authorization

```python
# tests/unit/test_authorization.py
import pytest
from src.models.user import User, UserRole
from src.models.permission import Permission


@pytest.fixture
def admin_user():
    user = User(email="admin@example.com", role=UserRole.ADMIN)
    user.permissions = [Permission(name="admin:access")]
    return user


@pytest.fixture
def regular_user():
    user = User(email="user@example.com", role=UserRole.USER)
    user.permissions = [Permission(name="products:read")]
    return user


def test_admin_has_permission(admin_user):
    assert admin_user.has_permission("admin:access")
    assert not admin_user.has_permission("products:read")


def test_regular_user_permissions(regular_user):
    assert regular_user.has_permission("products:read")
    assert not regular_user.has_permission("admin:access")


def test_has_any_permission(regular_user):
    assert regular_user.has_any_permission("products:read", "admin:access")
    assert not regular_user.has_any_permission("admin:access", "admin:settings")
```

## Comparison with .NET

| .NET | Python/FastAPI |
|------|----------------|
| `[Authorize(Roles = "Admin")]` | `Depends(require_role(UserRole.ADMIN))` |
| `[Authorize(Policy = "CanEdit")]` | `Depends(require_permission("edit"))` |
| `IAuthorizationService` | Service-level permission checks |
| `AuthorizationHandler<TRequirement>` | Custom dependency functions |
| `ClaimsPrincipal.IsInRole()` | `user.role == UserRole.ADMIN` |
| `ClaimsPrincipal.HasClaim()` | `user.has_permission()` |

## Best Practices

### 1. Use Specific Permissions

```python
# Good - specific permissions
PRODUCTS_CREATE = "products:create"
PRODUCTS_UPDATE = "products:update"

# Avoid - too broad
CAN_EDIT = "can_edit"  # Edit what?
```

### 2. Check Authorization in Services

```python
# Good - authorization in service
class ProductService:
    async def delete(self, product_id: UUID, user: User):
        product = await self.get_by_id(product_id)
        if product.created_by != user.id and not user.is_admin:
            raise AuthorizationError("Not authorized")
        await self.db.delete(product)

# Avoid - only checking at route level
@router.delete("/{id}")
async def delete(id: UUID, user: User = Depends(get_current_user)):
    # No ownership check!
    await service.delete(id)
```

### 3. Fail Securely

```python
# Good - don't leak information
raise HTTPException(403, "Insufficient permissions")

# Avoid - reveals too much
raise HTTPException(403, f"User {user.id} lacks permission {perm}")
```

### 4. Audit Authorization Failures

```python
async def permission_checker(current_user: User = Depends(get_current_user)):
    if not current_user.has_permission(permission):
        logger.warning(
            "authorization_denied",
            user_id=str(current_user.id),
            permission=permission,
            endpoint=request.url.path,
        )
        raise HTTPException(403, "Insufficient permissions")
    return current_user
```

### 5. Use Least Privilege

```python
# Good - minimal permissions per endpoint
@router.get("")
async def list_products(
    user: User = Depends(require_permission(Permissions.PRODUCTS_READ)),
): ...

@router.post("")
async def create_product(
    user: User = Depends(require_permission(Permissions.PRODUCTS_CREATE)),
): ...

# Avoid - overly broad access
@router.get("")
@router.post("")
async def products_endpoint(
    user: User = Depends(require_permission(Permissions.PRODUCTS_ADMIN)),  # Too broad
): ...
```
