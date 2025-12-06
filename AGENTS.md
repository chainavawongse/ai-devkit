# AI Agent Instructions

This file provides instructions for AI coding assistants (Claude Code, GitHub Copilot, Cursor, Codex, Gemini, etc.) when working on this project.

> **Tool-specific setup:**
> - **Claude Code**: Symlinked as `CLAUDE.md` (auto-detected)
> - **Gemini Code Assist**: Symlinked as `GEMINI.md` and `.gemini/instructions.md` (auto-detected)
> - **GitHub Copilot**: Symlinked as `.github/copilot-instructions.md` (auto-detected)
> - **Cursor**: Condensed version in `.cursorrules` (auto-detected)
> - **Others**: Reference `AGENTS.md` in your prompt or context

## Project Overview

This is a full-stack application with:
- **Frontend**: React/TypeScript with Vite, Tailwind CSS, React Query, and Zustand. Guidelines in `frontend/`
- **Backend (.NET)**: .NET 8 API with Clean Architecture, CQRS, MediatR, and Entity Framework Core. Guidelines in `backend-dotnet/`
- **Backend (Python)**: FastAPI with Pydantic, SQLAlchemy 2.0, and async PostgreSQL. Guidelines in `backend-python/`

Identify the relevant stack based on the task and read the appropriate documentation.

## Documentation Priority

When implementing features, read documentation in this order:

---

### Frontend (React/TypeScript)

1. **Always read first:**
   - `frontend/DEVELOPMENT.md` - Entry point and quick reference
   - `frontend/standards/naming-conventions.md` - File and code naming rules

2. **Read based on task type:**

   | Task | Required Reading |
   |------|------------------|
   | New component | `frontend/patterns/component-patterns.md`, `frontend/examples/component-template.tsx` |
   | API integration | `frontend/patterns/api-integration.md`, `frontend/examples/api-template.ts` |
   | Form handling | `frontend/patterns/form-patterns.md` |
   | State management | `frontend/architecture/state-management.md` |
   | Writing tests | `frontend/testing/testing-strategy.md`, `frontend/examples/test-template.test.tsx` |
   | New feature module | `frontend/architecture/folder-structure.md` |
   | Error handling | `frontend/architecture/error-handling.md` |
   | Performance work | `frontend/patterns/performance.md` |
   | Security concerns | `frontend/architecture/security.md` |

3. **Reference as needed:**
   - `frontend/standards/typescript-guidelines.md`
   - `frontend/standards/accessibility.md`
   - `frontend/standards/code-quality.md`

---

### Backend (.NET API)

1. **Always read first:**
   - `backend-dotnet/DEVELOPMENT.md` - Entry point and quick reference
   - `backend-dotnet/api/standards/naming-conventions.md` - File and code naming rules

2. **Read based on task type:**

   | Task | Required Reading |
   |------|------------------|
   | New endpoint | `backend-dotnet/api/patterns/controller-patterns.md`, `backend-dotnet/api/examples/ControllerTemplate.cs` |
   | Command handler | `backend-dotnet/api/patterns/cqrs-mediatr.md`, `backend-dotnet/api/examples/CommandHandlerTemplate.cs` |
   | Query handler | `backend-dotnet/api/patterns/cqrs-mediatr.md`, `backend-dotnet/api/examples/QueryHandlerTemplate.cs` |
   | Validation | `backend-dotnet/api/patterns/validation-patterns.md`, `backend-dotnet/api/examples/ValidatorTemplate.cs` |
   | Entity/DbContext | `backend-dotnet/api/data/entity-framework.md`, `backend-dotnet/api/examples/EntityTemplate.cs` |
   | Repository | `backend-dotnet/api/data/entity-framework.md`, `backend-dotnet/api/examples/RepositoryTemplate.cs` |
   | OData queries | `backend-dotnet/api/patterns/odata-patterns.md` |
   | Error handling | `backend-dotnet/api/patterns/error-handling.md` |
   | Authentication | `backend-dotnet/api/security/authentication.md` |
   | Authorization | `backend-dotnet/api/security/authorization.md` |
   | Middleware | `backend-dotnet/api/patterns/middleware-patterns.md` |
   | Logging | `backend-dotnet/api/observability/logging-monitoring.md` |
   | Writing tests | `backend-dotnet/api/testing/testing-strategy.md` |

3. **Reference as needed:**
   - `backend-dotnet/api/architecture/solution-structure.md`
   - `backend-dotnet/api/architecture/dependency-injection.md`
   - `backend-dotnet/api/architecture/configuration.md`
   - `backend-dotnet/api/patterns/mapping-patterns.md`

---

### Backend (Python/FastAPI)

1. **Always read first:**
   - `backend-python/DEVELOPMENT.md` - Entry point and quick reference
   - `backend-python/api/standards/naming-conventions.md` - File and code naming rules

2. **Read based on task type:**

   | Task | Required Reading |
   |------|------------------|
   | New endpoint | `backend-python/api/patterns/router-patterns.md`, `backend-python/api/examples/router_template.py` |
   | Business logic | `backend-python/api/patterns/service-patterns.md`, `backend-python/api/examples/service_template.py` |
   | Pydantic schemas | `backend-python/api/patterns/pydantic-patterns.md`, `backend-python/api/examples/schema_template.py` |
   | SQLAlchemy model | `backend-python/api/data/sqlalchemy.md`, `backend-python/api/examples/model_template.py` |
   | Database migration | `backend-python/api/data/alembic.md` |
   | Vector search | `backend-python/api/data/pgvector.md` |
   | Error handling | `backend-python/api/patterns/error-handling.md` |
   | Async patterns | `backend-python/api/patterns/async-patterns.md` |
   | Authentication | `backend-python/api/security/authentication.md` |
   | Authorization | `backend-python/api/security/authorization.md` |
   | Logging/tracing | `backend-python/api/observability/logging-tracing.md` |
   | Unit tests | `backend-python/api/testing/unit-testing.md`, `backend-python/api/examples/test_templates/unit_test_template.py` |
   | Integration tests | `backend-python/api/testing/integration-testing.md`, `backend-python/api/examples/test_templates/integration_test_template.py` |

3. **Reference as needed:**
   - `backend-python/api/architecture/project-structure.md`
   - `backend-python/api/architecture/dependency-injection.md`

## Code Generation Rules

---

### Frontend (React/TypeScript)

#### Always Do

- Follow naming conventions exactly (PascalCase components, camelCase hooks, etc.)
- Use TypeScript strict mode - no `any` types
- Use `@/` path aliases for imports
- Include JSDoc comments for component props
- Add `aria-label` for icon-only buttons
- Use React Query for ALL server state
- Use Zod schemas for ALL form validation
- Co-locate tests with source files (`Component.test.tsx` next to `Component.tsx`)
- Export from feature's `index.ts` for public API

#### Never Do

- Never use `any` type - use `unknown` with type guards
- Never store API data in Zustand - use React Query
- Never use `dangerouslySetInnerHTML` without DOMPurify
- Never log sensitive data (tokens, passwords, PII)
- Never use default exports for components (use named exports)
- Never use `.spec.ts` for unit tests (use `.test.ts`)
- Never skip error handling for mutations
- Never create files outside the established folder structure

---

### Backend (.NET API)

#### Always Do

- Follow Clean Architecture layer separation (Api → Services → Contracts/Data → Shared)
- Use primary constructors for DI in classes
- Use records for DTOs, commands, queries, and events
- Use FluentValidation for all input validation
- Return `IActionResult` from controllers, dispatch via MediatR
- Use `AsNoTracking()` for read-only queries
- Include XML documentation for public APIs
- Use strongly-typed configuration with `IOptions<T>`
- Log with structured logging (Serilog) including correlation IDs
- Use `CancellationToken` on all async operations

#### Never Do

- Never inject DbContext directly into controllers (use repositories/handlers)
- Never use `DateTime.Now` (use `DateTime.UtcNow`)
- Never catch generic `Exception` without re-throwing or logging
- Never store secrets in appsettings.json (use user secrets or environment variables)
- Never skip validation on commands/queries
- Never use `.Result` or `.Wait()` on async calls (async all the way)
- Never expose entities directly from API (use DTOs)
- Never use `Include()` without considering query performance

---

### Backend (Python/FastAPI)

#### Always Do

- Follow PEP 8 naming conventions (snake_case functions, PascalCase classes)
- Use type hints on all functions and methods
- Use Pydantic models for all request/response validation
- Use `async`/`await` for all I/O operations (database, HTTP)
- Use FastAPI's `Depends()` for dependency injection
- Use structlog for structured logging with context
- Use `datetime.now(timezone.utc)` instead of `datetime.utcnow()`
- Handle exceptions with custom exception classes, not HTTPException in services
- Use SQLAlchemy 2.0 style with `select()` not legacy `query()`

#### Never Do

- Never use `any` type - use proper type hints or `object`
- Never use sync database operations (use asyncpg)
- Never block the event loop (no `time.sleep()`, use `asyncio.sleep()`)
- Never use `.Result` or `.Wait()` patterns from sync code
- Never store secrets in code or config files (use environment variables)
- Never skip Pydantic validation for API inputs
- Never use lazy loading for relationships (use explicit `selectinload`)
- Never catch generic `Exception` without re-raising or logging

---

### When Uncertain

Ask the user for clarification when:
- The task requires choosing between multiple valid architectural approaches
- The feature doesn't fit clearly into an existing feature module
- Security implications are unclear
- The request conflicts with established patterns
- Performance trade-offs need user input

Do NOT ask when:
- The pattern is clearly documented
- It's a straightforward implementation following existing examples
- The decision is easily reversible

## File Structure Decisions

### Frontend

```
Is it a new feature?
├── YES → Create in src/features/[feature-name]/
│         ├── components/
│         ├── hooks/
│         ├── api/
│         ├── types/
│         └── index.ts (public exports)
│
└── NO → Is it shared across features?
         ├── YES → Is it a component?
         │         ├── YES → src/components/ui/ or src/components/layout/
         │         └── NO → src/hooks/ or src/lib/utils/
         │
         └── NO → Keep in the feature that owns it
```

### Backend (.NET)

```
src/
├── MyApp.Api/              # Controllers, middleware, Program.cs
├── MyApp.Services/         # Command/query handlers, validators, services
├── MyApp.Contracts/        # DTOs, commands, queries, interfaces
├── MyApp.Data/             # DbContext, entities, repositories, migrations
└── MyApp.Shared/           # Exceptions, utilities, cross-cutting concerns
```

### Backend (Python)

```
src/
├── main.py                 # FastAPI app entry point
├── api/                    # Routers (endpoints)
│   ├── routes/
│   └── dependencies.py     # Shared Depends() functions
├── services/               # Business logic
├── models/                 # SQLAlchemy models
├── schemas/                # Pydantic DTOs
├── core/                   # Config, security, exceptions
└── utils/                  # Shared utilities
```

## Code Patterns Quick Reference

### Frontend

#### Component Structure

```typescript
// 1. Imports
import { memo } from 'react';
import type { Product } from '../types/product.types';

// 2. Types
type ProductCardProps = {
  product: Product;
  onEdit?: (id: string) => void;
};

// 3. Component
export const ProductCard = memo(function ProductCard({
  product,
  onEdit,
}: ProductCardProps) {
  return (/* JSX */);
});
```

#### API Hook Structure

```typescript
// Query keys factory
export const productKeys = {
  all: ['products'] as const,
  list: (filters?: Filters) => [...productKeys.all, 'list', filters] as const,
  detail: (id: string) => [...productKeys.all, 'detail', id] as const,
};

// Query hook
export function useProducts(filters?: Filters) {
  return useQuery({
    queryKey: productKeys.list(filters),
    queryFn: async () => {
      const { data } = await apiClient.get<Product[]>('/products', { params: filters });
      return data;
    },
  });
}

// Mutation hook
export function useCreateProduct() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (product: CreateProductRequest) => {
      const { data } = await apiClient.post<Product>('/products', product);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: productKeys.all });
      toast.success('Product created');
    },
  });
}
```

#### Form Structure

```typescript
// 1. Zod schema
const schema = z.object({
  name: z.string().min(1, 'Required'),
  email: z.string().email('Invalid email'),
});

// 2. Infer type
type FormData = z.infer<typeof schema>;

// 3. Use with React Hook Form
const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
  resolver: zodResolver(schema),
});
```

### Backend (.NET)

#### Command Handler

```csharp
public class CreateProductCommandHandler(
    IProductRepository repository,
    IMapper mapper,
    ILogger<CreateProductCommandHandler> logger
) : IRequestHandler<CreateProductCommand, ProductDto>
{
    public async Task<ProductDto> Handle(
        CreateProductCommand request,
        CancellationToken cancellationToken)
    {
        var entity = mapper.Map<ProductEntity>(request.Dto);
        entity.CreatedBy = request.UserId;
        entity.CreatedAt = DateTime.UtcNow;

        await repository.AddAsync(entity, cancellationToken);

        logger.LogInformation("Product {ProductId} created", entity.Id);

        return mapper.Map<ProductDto>(entity);
    }
}

public record CreateProductCommand(CreateProductDto Dto, Guid UserId)
    : IRequest<ProductDto>;
```

#### Controller Action

```csharp
[HttpPost]
[ProducesResponseType(typeof(ProductDto), StatusCodes.Status201Created)]
public async Task<IActionResult> Create(
    [FromBody] CreateProductDto dto,
    CancellationToken ct)
{
    var command = new CreateProductCommand(dto, CurrentUserId);
    var result = await _mediator.Send(command, ct);
    return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
}
```

#### Validator

```csharp
public class CreateProductDtoValidator : AbstractValidator<CreateProductDto>
{
    public CreateProductDtoValidator(IProductRepository repository)
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name is required")
            .MaximumLength(200);

        RuleFor(x => x.Sku)
            .NotEmpty()
            .MustAsync(async (sku, ct) => !await repository.ExistsBySkuAsync(sku, ct))
            .WithMessage("SKU already exists");
    }
}
```

### Backend (Python)

#### Router Structure

```python
from fastapi import APIRouter, Depends, status
from src.api.dependencies import get_current_user, get_product_service

router = APIRouter(prefix="/products", tags=["products"])

@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(
    product_id: UUID,
    service: ProductService = Depends(get_product_service),
    current_user: User = Depends(get_current_user),
) -> ProductResponse:
    return await service.get_by_id(product_id)
```

#### Service Structure

```python
class ProductService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, product_id: UUID) -> Product:
        result = await self.db.execute(
            select(Product).where(Product.id == product_id)
        )
        product = result.scalar_one_or_none()
        if not product:
            raise NotFoundError(f"Product {product_id} not found")
        return product
```

#### Pydantic Schema

```python
class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    price: Decimal = Field(gt=0)
    sku: str = Field(pattern=r"^[A-Z0-9-]+$")

class ProductResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    name: str
    price: Decimal
    created_at: datetime
```

## Testing Requirements

### Frontend

- Unit tests required for: components, hooks, utility functions
- E2E tests required for: critical user flows (auth, checkout, etc.)
- Use `renderWithProviders` for components needing React Query/Router
- Use `vi.mock()` to mock API client in unit tests
- Use accessible queries: `getByRole`, `getByLabelText` over `getByTestId`

### Backend (.NET)

- Unit tests for: handlers, validators, services
- Integration tests for: repository queries, API endpoints
- Use xUnit + Moq + FluentAssertions
- Use `WebApplicationFactory<Program>` for API tests
- Mock repositories and external services in handler tests

### Backend (Python)

- Unit tests for: services, validators, utility functions
- Integration tests for: API endpoints with real database
- Use pytest + pytest-asyncio + pytest-mock
- Use testcontainers for PostgreSQL in integration tests
- Mock database session in unit tests with AsyncMock

## Commit Message Format

```
<type>(<scope>): <description>

Types: feat, fix, refactor, test, docs, chore, style, perf
Example: feat(auth): add password reset flow
```

## Common Tasks

### Frontend

#### Creating a new feature

```bash
# 1. Create folder structure
mkdir -p src/features/[name]/{components,hooks,api,types}

# 2. Create index.ts for public exports
touch src/features/[name]/index.ts

# 3. Follow patterns in frontend/architecture/folder-structure.md
```

#### Adding a new API endpoint

1. Add types in `src/features/[name]/types/[name].types.ts`
2. Create query/mutation hooks in `src/features/[name]/api/[name]Api.ts`
3. Export from `src/features/[name]/index.ts`
4. Follow patterns in `frontend/patterns/api-integration.md`

#### Adding a new form

1. Define Zod schema
2. Create form component using React Hook Form
3. Handle both client and server validation errors
4. Follow patterns in `frontend/patterns/form-patterns.md`

### Backend (.NET)

#### Adding a new endpoint

1. Create DTO in `MyApp.Contracts/Dtos/`
2. Create Command/Query in `MyApp.Contracts/Commands/` or `Queries/`
3. Create Handler in `MyApp.Services/Handlers/`
4. Create Validator in `MyApp.Services/Validators/`
5. Add controller action in `MyApp.Api/Controllers/`
6. Follow patterns in `backend-dotnet/api/patterns/`

#### Adding a new entity

1. Create entity in `MyApp.Data/Entities/`
2. Create configuration in `MyApp.Data/Configurations/`
3. Add DbSet to `AppDbContext`
4. Create migration: `dotnet ef migrations add MigrationName`
5. Follow patterns in `backend-dotnet/api/data/entity-framework.md`

### Backend (Python)

#### Adding a new endpoint

1. Create/update schema in `src/schemas/`
2. Create/update service in `src/services/`
3. Add route in `src/api/routes/`
4. Register router in `src/main.py`
5. Add tests in `tests/unit/` and `tests/integration/`
6. Follow patterns in `backend-python/api/patterns/`

#### Adding a new model

1. Create model in `src/models/`
2. Import in `src/models/__init__.py`
3. Create migration: `uv run alembic revision --autogenerate -m "description"`
4. Run migration: `uv run alembic upgrade head`
5. Follow patterns in `backend-python/api/data/sqlalchemy.md`
