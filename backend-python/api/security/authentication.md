# Authentication

## Overview

This guide covers JWT authentication and OAuth 2.0 social login integration for FastAPI applications.

## JWT Authentication

### Dependencies

```bash
uv add python-jose[cryptography] passlib[bcrypt]
```

### Configuration

```python
# src/core/config.py
from pydantic import SecretStr
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # JWT
    jwt_secret_key: SecretStr
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 7

    # OAuth - Google
    google_client_id: str | None = None
    google_client_secret: SecretStr | None = None

    # OAuth - GitHub
    github_client_id: str | None = None
    github_client_secret: SecretStr | None = None

    # OAuth - Microsoft
    microsoft_client_id: str | None = None
    microsoft_client_secret: SecretStr | None = None

    # OAuth - Apple
    apple_client_id: str | None = None
    apple_team_id: str | None = None
    apple_key_id: str | None = None
    apple_private_key: SecretStr | None = None
```

### Security Utilities

```python
# src/core/security.py
from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import UUID

from jose import JWTError, jwt
from passlib.context import CryptContext

from src.core.config import get_settings

settings = get_settings()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against a hash."""
    return pwd_context.verify(plain_password, hashed_password)


def hash_password(password: str) -> str:
    """Hash a password."""
    return pwd_context.hash(password)


def create_access_token(
    subject: UUID | str,
    expires_delta: timedelta | None = None,
    additional_claims: dict[str, Any] | None = None,
) -> str:
    """Create a JWT access token."""
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(
            minutes=settings.jwt_access_token_expire_minutes
        )

    to_encode = {
        "sub": str(subject),
        "exp": expire,
        "type": "access",
    }
    if additional_claims:
        to_encode.update(additional_claims)

    return jwt.encode(
        to_encode,
        settings.jwt_secret_key.get_secret_value(),
        algorithm=settings.jwt_algorithm,
    )


def create_refresh_token(subject: UUID | str) -> str:
    """Create a JWT refresh token."""
    expire = datetime.now(timezone.utc) + timedelta(
        days=settings.jwt_refresh_token_expire_days
    )

    to_encode = {
        "sub": str(subject),
        "exp": expire,
        "type": "refresh",
    }

    return jwt.encode(
        to_encode,
        settings.jwt_secret_key.get_secret_value(),
        algorithm=settings.jwt_algorithm,
    )


def decode_token(token: str) -> dict[str, Any]:
    """Decode and validate a JWT token."""
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key.get_secret_value(),
            algorithms=[settings.jwt_algorithm],
        )
        return payload
    except JWTError as e:
        raise InvalidTokenError(str(e))


class InvalidTokenError(Exception):
    """Raised when token validation fails."""
    pass
```

### Token Schemas

```python
# src/schemas/auth.py
from pydantic import BaseModel, EmailStr, Field


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int  # seconds


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    name: str = Field(min_length=1, max_length=100)
```

### Authentication Dependencies

```python
# src/api/dependencies.py
from uuid import UUID
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.database import get_db
from src.core.security import decode_token, InvalidTokenError
from src.models.user import User

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Extract and validate user from JWT token."""
    token = credentials.credentials

    try:
        payload = decode_token(token)
    except InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Verify token type
    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
        )

    # Get user from database
    user_id = UUID(payload["sub"])
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account is disabled",
        )

    return user


async def get_current_user_optional(
    credentials: HTTPAuthorizationCredentials | None = Depends(
        HTTPBearer(auto_error=False)
    ),
    db: AsyncSession = Depends(get_db),
) -> User | None:
    """Get current user if authenticated, None otherwise."""
    if not credentials:
        return None

    try:
        return await get_current_user(credentials, db)
    except HTTPException:
        return None
```

### Auth Routes

```python
# src/api/routes/auth.py
from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.api.dependencies import get_db, get_current_user
from src.core.config import get_settings
from src.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
    InvalidTokenError,
)
from src.models.user import User
from src.schemas.auth import (
    LoginRequest,
    TokenResponse,
    RefreshTokenRequest,
    RegisterRequest,
)

router = APIRouter(prefix="/auth", tags=["auth"])
settings = get_settings()


@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(
    data: RegisterRequest,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Register a new user."""
    # Check if email exists
    result = await db.execute(select(User).where(User.email == data.email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    # Create user
    user = User(
        email=data.email,
        name=data.name,
        password_hash=hash_password(data.password),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    # Generate tokens
    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        expires_in=settings.jwt_access_token_expire_minutes * 60,
    )


@router.post("/login")
async def login(
    data: LoginRequest,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Authenticate user and return tokens."""
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()

    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account is disabled",
        )

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        expires_in=settings.jwt_access_token_expire_minutes * 60,
    )


@router.post("/refresh")
async def refresh_token(
    data: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Refresh access token using refresh token."""
    try:
        payload = decode_token(data.refresh_token)
    except InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
        )

    user_id = UUID(payload["sub"])
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or disabled",
        )

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        expires_in=settings.jwt_access_token_expire_minutes * 60,
    )


@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)) -> UserResponse:
    """Get current user profile."""
    return UserResponse.model_validate(current_user)
```

## OAuth 2.0 Social Login

### OAuth Service

```python
# src/services/oauth_service.py
from dataclasses import dataclass
from enum import Enum
import httpx

from src.core.config import get_settings

settings = get_settings()


class OAuthProvider(str, Enum):
    GOOGLE = "google"
    GITHUB = "github"
    MICROSOFT = "microsoft"
    APPLE = "apple"


@dataclass
class OAuthUserInfo:
    provider: OAuthProvider
    provider_user_id: str
    email: str
    name: str | None
    picture_url: str | None


class OAuthService:
    def __init__(self, http_client: httpx.AsyncClient):
        self.client = http_client

    async def get_user_info(
        self,
        provider: OAuthProvider,
        access_token: str,
    ) -> OAuthUserInfo:
        """Get user info from OAuth provider."""
        if provider == OAuthProvider.GOOGLE:
            return await self._get_google_user_info(access_token)
        elif provider == OAuthProvider.GITHUB:
            return await self._get_github_user_info(access_token)
        elif provider == OAuthProvider.MICROSOFT:
            return await self._get_microsoft_user_info(access_token)
        else:
            raise ValueError(f"Unsupported provider: {provider}")

    async def _get_google_user_info(self, access_token: str) -> OAuthUserInfo:
        response = await self.client.get(
            "https://www.googleapis.com/oauth2/v2/userinfo",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        response.raise_for_status()
        data = response.json()

        return OAuthUserInfo(
            provider=OAuthProvider.GOOGLE,
            provider_user_id=data["id"],
            email=data["email"],
            name=data.get("name"),
            picture_url=data.get("picture"),
        )

    async def _get_github_user_info(self, access_token: str) -> OAuthUserInfo:
        # Get user profile
        response = await self.client.get(
            "https://api.github.com/user",
            headers={
                "Authorization": f"Bearer {access_token}",
                "Accept": "application/vnd.github+json",
            },
        )
        response.raise_for_status()
        data = response.json()

        # Get primary email (may not be in profile)
        email = data.get("email")
        if not email:
            email_response = await self.client.get(
                "https://api.github.com/user/emails",
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Accept": "application/vnd.github+json",
                },
            )
            email_response.raise_for_status()
            emails = email_response.json()
            primary = next((e for e in emails if e["primary"]), emails[0])
            email = primary["email"]

        return OAuthUserInfo(
            provider=OAuthProvider.GITHUB,
            provider_user_id=str(data["id"]),
            email=email,
            name=data.get("name"),
            picture_url=data.get("avatar_url"),
        )

    async def _get_microsoft_user_info(self, access_token: str) -> OAuthUserInfo:
        response = await self.client.get(
            "https://graph.microsoft.com/v1.0/me",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        response.raise_for_status()
        data = response.json()

        return OAuthUserInfo(
            provider=OAuthProvider.MICROSOFT,
            provider_user_id=data["id"],
            email=data.get("mail") or data.get("userPrincipalName"),
            name=data.get("displayName"),
            picture_url=None,  # Requires separate Graph API call
        )
```

### OAuth Routes

```python
# src/api/routes/oauth.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.api.dependencies import get_db
from src.core.security import create_access_token, create_refresh_token
from src.models.user import User, OAuthAccount
from src.schemas.auth import TokenResponse, OAuthCallbackRequest
from src.services.oauth_service import OAuthService, OAuthProvider

router = APIRouter(prefix="/auth/oauth", tags=["oauth"])


@router.post("/{provider}/callback")
async def oauth_callback(
    provider: OAuthProvider,
    data: OAuthCallbackRequest,
    db: AsyncSession = Depends(get_db),
    oauth_service: OAuthService = Depends(get_oauth_service),
) -> TokenResponse:
    """Handle OAuth callback and authenticate/register user."""
    # Get user info from provider
    try:
        user_info = await oauth_service.get_user_info(provider, data.access_token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Failed to verify OAuth token",
        )

    # Check if OAuth account exists
    result = await db.execute(
        select(OAuthAccount)
        .where(
            OAuthAccount.provider == provider,
            OAuthAccount.provider_user_id == user_info.provider_user_id,
        )
    )
    oauth_account = result.scalar_one_or_none()

    if oauth_account:
        # Existing OAuth account - return tokens
        user = oauth_account.user
    else:
        # Check if user with email exists
        result = await db.execute(
            select(User).where(User.email == user_info.email)
        )
        user = result.scalar_one_or_none()

        if user:
            # Link OAuth account to existing user
            oauth_account = OAuthAccount(
                user_id=user.id,
                provider=provider,
                provider_user_id=user_info.provider_user_id,
            )
            db.add(oauth_account)
        else:
            # Create new user
            user = User(
                email=user_info.email,
                name=user_info.name or user_info.email.split("@")[0],
                picture_url=user_info.picture_url,
            )
            db.add(user)
            await db.flush()

            # Create OAuth account link
            oauth_account = OAuthAccount(
                user_id=user.id,
                provider=provider,
                provider_user_id=user_info.provider_user_id,
            )
            db.add(oauth_account)

        await db.commit()
        await db.refresh(user)

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        expires_in=settings.jwt_access_token_expire_minutes * 60,
    )
```

### OAuth Account Model

```python
# src/models/user.py
from uuid import UUID
from sqlalchemy import String, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.models.base import Base, UUIDPrimaryKeyMixin, TimestampMixin


class User(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    picture_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_active: Mapped[bool] = mapped_column(default=True)

    # Relationships
    oauth_accounts: Mapped[list["OAuthAccount"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
    )


class OAuthAccount(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "oauth_accounts"

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    provider: Mapped[str] = mapped_column(String(50), nullable=False)
    provider_user_id: Mapped[str] = mapped_column(String(255), nullable=False)

    # Relationships
    user: Mapped["User"] = relationship(back_populates="oauth_accounts")

    __table_args__ = (
        UniqueConstraint("provider", "provider_user_id", name="uq_oauth_provider_user"),
    )
```

## API Key Authentication

For service-to-service or API integrations:

```python
# src/api/dependencies.py
from fastapi import Depends, HTTPException, Security, status
from fastapi.security import APIKeyHeader

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


async def get_api_key(
    api_key: str | None = Security(api_key_header),
    db: AsyncSession = Depends(get_db),
) -> APIKey:
    """Validate API key and return associated record."""
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="API key required",
        )

    result = await db.execute(
        select(APIKey)
        .where(APIKey.key_hash == hash_api_key(api_key))
        .where(APIKey.is_active == True)
    )
    api_key_record = result.scalar_one_or_none()

    if not api_key_record:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )

    # Update last used timestamp
    api_key_record.last_used_at = datetime.utcnow()
    await db.commit()

    return api_key_record
```

## Comparison with .NET

| .NET | Python/FastAPI |
|------|----------------|
| `[Authorize]` | `Depends(get_current_user)` |
| `IAuthenticationService` | Security utilities + dependencies |
| `JwtBearerDefaults` | `HTTPBearer` |
| `ClaimsPrincipal` | `User` model |
| `AddAuthentication().AddJwtBearer()` | Manual JWT decode in dependency |
| `AddGoogle()`, `AddGitHub()` | Custom OAuth service |

## Best Practices

### 1. Never Store Plain Passwords

```python
# Good - use bcrypt
password_hash = hash_password(password)

# Verify without exposing hash
if verify_password(plain, hashed):
    ...
```

### 2. Use Short-Lived Access Tokens

```python
# Access tokens: 15-30 minutes
jwt_access_token_expire_minutes: int = 30

# Refresh tokens: 7-30 days
jwt_refresh_token_expire_days: int = 7
```

### 3. Validate Token Type

```python
# Prevent refresh token from being used as access token
if payload.get("type") != "access":
    raise HTTPException(401, "Invalid token type")
```

### 4. Use Secure Secrets

```python
# Generate secure secret
import secrets
jwt_secret = secrets.token_urlsafe(32)

# Store in environment, never in code
JWT_SECRET_KEY=your-secret-key
```

### 5. Handle OAuth Failures Gracefully

```python
try:
    user_info = await oauth_service.get_user_info(provider, token)
except httpx.HTTPError:
    raise HTTPException(502, "OAuth provider unavailable")
except Exception:
    raise HTTPException(401, "OAuth verification failed")
```
