# Solution Structure

Clean Architecture with CQRS pattern for scalable, maintainable .NET APIs.

## Complete Structure

```
MySolution/
├── src/
│   ├── MyApp.Api/                        # Presentation layer
│   │   ├── Controllers/
│   │   │   ├── ProductsController.cs
│   │   │   └── OrdersController.cs
│   │   ├── Filters/
│   │   │   ├── ApiExceptionFilter.cs
│   │   │   └── ValidationFilter.cs
│   │   ├── Middleware/
│   │   │   ├── CorrelationIdMiddleware.cs
│   │   │   └── AuditMiddleware.cs
│   │   ├── Extensions/
│   │   │   └── ServiceCollectionExtensions.cs
│   │   ├── appsettings.json
│   │   ├── appsettings.Development.json
│   │   └── Program.cs
│   │
│   ├── MyApp.Services/                   # Application/Business logic layer
│   │   ├── Handlers/
│   │   │   ├── Commands/
│   │   │   │   ├── CreateProductCommandHandler.cs
│   │   │   │   ├── UpdateProductCommandHandler.cs
│   │   │   │   └── DeleteProductCommandHandler.cs
│   │   │   └── Queries/
│   │   │       ├── GetProductByIdQueryHandler.cs
│   │   │       └── GetProductsQueryHandler.cs
│   │   ├── Behaviors/
│   │   │   ├── ValidationBehavior.cs
│   │   │   └── LoggingBehavior.cs
│   │   ├── Services/
│   │   │   ├── ProductAccessService.cs
│   │   │   └── ProductPersistenceService.cs
│   │   ├── Validators/
│   │   │   ├── CreateProductDtoValidator.cs
│   │   │   └── UpdateProductDtoValidator.cs
│   │   └── Mapping/
│   │       └── ProductMappingProfile.cs
│   │
│   ├── MyApp.Contracts/                  # Contracts/Interfaces layer
│   │   ├── Commands/
│   │   │   ├── CreateProductCommand.cs
│   │   │   ├── UpdateProductCommand.cs
│   │   │   └── DeleteProductCommand.cs
│   │   ├── Queries/
│   │   │   ├── GetProductByIdQuery.cs
│   │   │   └── GetProductsQuery.cs
│   │   ├── Dtos/
│   │   │   ├── Products/
│   │   │   │   ├── CreateProductDto.cs
│   │   │   │   ├── UpdateProductDto.cs
│   │   │   │   ├── PatchProductDto.cs
│   │   │   │   └── ProductDto.cs
│   │   │   └── Common/
│   │   │       └── PaginatedResultDto.cs
│   │   ├── Interfaces/
│   │   │   ├── IProductRepository.cs
│   │   │   ├── IProductAccessService.cs
│   │   │   └── IProductPersistenceService.cs
│   │   ├── Models/
│   │   │   └── ProductFilter.cs
│   │   └── Enums/
│   │       └── ProductStatus.cs
│   │
│   ├── MyApp.Data/                       # Infrastructure/Data layer
│   │   ├── AppDbContext.cs
│   │   ├── Entities/
│   │   │   ├── ProductEntity.cs
│   │   │   ├── OrderEntity.cs
│   │   │   └── BaseEntity.cs
│   │   ├── Configurations/
│   │   │   ├── ProductEntityConfiguration.cs
│   │   │   └── OrderEntityConfiguration.cs
│   │   ├── Repositories/
│   │   │   ├── Repository.cs
│   │   │   └── ProductRepository.cs
│   │   ├── Interceptors/
│   │   │   └── AuditInterceptor.cs
│   │   └── Migrations/
│   │
│   └── MyApp.Shared/                     # Shared kernel
│       ├── Extensions/
│       │   ├── StringExtensions.cs
│       │   └── QueryableExtensions.cs
│       ├── Exceptions/
│       │   ├── EntityNotFoundException.cs
│       │   ├── ValidationException.cs
│       │   └── BusinessRuleException.cs
│       ├── Constants/
│       │   └── ErrorMessages.cs
│       └── Settings/
│           └── DatabaseSettings.cs
│
├── tests/
│   ├── MyApp.Tests.Unit/
│   │   ├── Handlers/
│   │   │   ├── Commands/
│   │   │   └── Queries/
│   │   ├── Validators/
│   │   └── Services/
│   │
│   ├── MyApp.Tests.Integration/
│   │   ├── Repositories/
│   │   └── Data/
│   │
│   └── MyApp.Tests.Api/
│       ├── Controllers/
│       └── Fixtures/
│
├── MySolution.sln
├── Directory.Build.props                 # Shared MSBuild properties
├── Directory.Packages.props              # Central package management
└── .editorconfig                         # Code style settings
```

---

## Layer Responsibilities

### MyApp.Api (Presentation)

**Purpose:** HTTP entry point, request/response handling

**Contains:**

- Controllers (thin, delegate to MediatR)
- Exception filters
- Middleware
- Swagger/OpenAPI configuration
- Program.cs / Startup configuration

**References:** Services, Contracts, Shared

```csharp
// Controller example - thin, delegates to MediatR
[ApiController]
[Route("api/[controller]")]
public class ProductsController(IMediator mediator) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<ProductDto>> Create(
        CreateProductDto dto,
        CancellationToken cancellationToken)
    {
        var command = new CreateProductCommand(dto, UserId);
        var result = await mediator.Send(command, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }
}
```

---

### MyApp.Services (Application)

**Purpose:** Business logic, orchestration, CQRS handlers

**Contains:**

- Command handlers (write operations)
- Query handlers (read operations)
- Pipeline behaviors (validation, logging)
- Domain services
- AutoMapper profiles
- FluentValidation validators

**References:** Contracts, Data, Shared

```csharp
// Handler example
public class CreateProductCommandHandler(
    IProductRepository repository,
    IMapper mapper,
    IEventPublisher eventPublisher
) : IRequestHandler<CreateProductCommand, ProductDto>
{
    public async Task<ProductDto> Handle(
        CreateProductCommand request,
        CancellationToken cancellationToken)
    {
        var entity = mapper.Map<ProductEntity>(request.Dto);
        await repository.AddAsync(entity, cancellationToken);
        await eventPublisher.PublishAsync(new ProductCreatedEvent(entity.Id));
        return mapper.Map<ProductDto>(entity);
    }
}
```

---

### MyApp.Contracts (Domain Contracts)

**Purpose:** DTOs, commands, queries, interfaces - the "what"

**Contains:**

- Command/Query record definitions
- Request/Response DTOs
- Service interfaces
- Repository interfaces
- Enums and constants
- Filter/sort models

**References:** None (leaf project)

```csharp
// Command definition
public record CreateProductCommand(
    CreateProductDto Dto,
    Guid UserId
) : IRequest<ProductDto>, IValidatable;

// DTO definition
public record CreateProductDto
{
    public required string Name { get; init; }
    public required decimal Price { get; init; }
    public string? Description { get; init; }
}
```

---

### MyApp.Data (Infrastructure)

**Purpose:** Persistence, database access, external integrations

**Contains:**

- EF Core DbContext
- Entity classes
- Entity configurations (Fluent API)
- Repository implementations
- Migrations
- Interceptors (audit, soft delete)

**References:** Contracts, Shared

```csharp
// Repository implementation
public class ProductRepository(AppDbContext context)
    : Repository<long, ProductEntity>(context), IProductRepository
{
    public async Task<ProductEntity?> GetBySkuAsync(
        string sku,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Sku == sku, cancellationToken);
    }
}
```

---

### MyApp.Shared (Cross-Cutting)

**Purpose:** Shared utilities, exceptions, constants

**Contains:**

- Extension methods
- Custom exceptions
- Constants
- Settings POCOs
- Common helpers

**References:** None (leaf project)

```csharp
// Custom exception
public class EntityNotFoundException : Exception
{
    public string EntityType { get; }
    public object EntityId { get; }

    public EntityNotFoundException(string entityType, object entityId)
        : base($"{entityType} with ID {entityId} was not found.")
    {
        EntityType = entityType;
        EntityId = entityId;
    }
}
```

---

## Project References

```
Api
 ├── Services
 │    ├── Contracts
 │    ├── Data
 │    │    ├── Contracts
 │    │    └── Shared
 │    └── Shared
 ├── Contracts
 └── Shared

Dependency Direction: Api → Services → Data → (Database)
                                    ↘ Contracts (interfaces)
                                    ↘ Shared (utilities)
```

### Dependency Rules

| Project | Can Reference | Cannot Reference |
|---------|--------------|------------------|
| Api | Services, Contracts, Shared | Data (directly) |
| Services | Contracts, Data, Shared | Api |
| Contracts | None | Any |
| Data | Contracts, Shared | Api, Services |
| Shared | None | Any |

---

## Central Package Management

Use `Directory.Packages.props` for consistent package versions:

```xml
<!-- Directory.Packages.props -->
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>
  <ItemGroup>
    <PackageVersion Include="MediatR" Version="12.5.0" />
    <PackageVersion Include="FluentValidation" Version="11.11.0" />
    <PackageVersion Include="AutoMapper" Version="13.0.1" />
    <PackageVersion Include="Npgsql.EntityFrameworkCore.PostgreSQL" Version="9.0.4" />
    <PackageVersion Include="Serilog.AspNetCore" Version="8.0.3" />
  </ItemGroup>
</Project>
```

Then in project files:

```xml
<!-- MyApp.Services.csproj -->
<ItemGroup>
  <PackageReference Include="MediatR" />
  <PackageReference Include="FluentValidation" />
</ItemGroup>
```

---

## Shared Build Properties

Use `Directory.Build.props` for common settings:

```xml
<!-- Directory.Build.props -->
<Project>
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
```

---

## Creating a New Solution

```bash
# Create solution
dotnet new sln -n MyApp

# Create projects
dotnet new webapi -n MyApp.Api -o src/MyApp.Api
dotnet new classlib -n MyApp.Services -o src/MyApp.Services
dotnet new classlib -n MyApp.Contracts -o src/MyApp.Contracts
dotnet new classlib -n MyApp.Data -o src/MyApp.Data
dotnet new classlib -n MyApp.Shared -o src/MyApp.Shared

# Create test projects
dotnet new xunit -n MyApp.Tests.Unit -o tests/MyApp.Tests.Unit
dotnet new xunit -n MyApp.Tests.Integration -o tests/MyApp.Tests.Integration
dotnet new xunit -n MyApp.Tests.Api -o tests/MyApp.Tests.Api

# Add to solution
dotnet sln add src/MyApp.Api
dotnet sln add src/MyApp.Services
dotnet sln add src/MyApp.Contracts
dotnet sln add src/MyApp.Data
dotnet sln add src/MyApp.Shared
dotnet sln add tests/MyApp.Tests.Unit
dotnet sln add tests/MyApp.Tests.Integration
dotnet sln add tests/MyApp.Tests.Api

# Add project references
dotnet add src/MyApp.Api reference src/MyApp.Services src/MyApp.Contracts src/MyApp.Shared
dotnet add src/MyApp.Services reference src/MyApp.Contracts src/MyApp.Data src/MyApp.Shared
dotnet add src/MyApp.Data reference src/MyApp.Contracts src/MyApp.Shared
```

---

## Anti-Patterns to Avoid

```
❌ Business logic in controllers
   Controllers should only: validate input, call MediatR, return response

❌ Direct DbContext usage in controllers
   Always go through Services layer

❌ Contracts referencing Data or Services
   Contracts must be a leaf project with no dependencies

❌ Circular references between features
   Features should be independent; use shared services for cross-feature logic

❌ Entities in DTOs
   Never expose EF entities in API responses; always map to DTOs

❌ Generic catch-all folders
   Avoid: src/Helpers/, src/Utils/, src/Misc/
```
