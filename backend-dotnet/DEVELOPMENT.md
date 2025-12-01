# .NET API Development Guidelines

Quick reference for .NET API development standards and best practices. This project uses Clean Architecture with CQRS pattern, optimized for working with AI coding assistants.

## Documentation Index

### Architecture
- **[Solution Structure](./api/architecture/solution-structure.md)** - Clean Architecture + CQRS organization
- **[Dependency Injection](./api/architecture/dependency-injection.md)** - Service registration patterns
- **[Configuration](./api/architecture/configuration.md)** - Settings, secrets, and environment management

### Patterns
- **[Controller Patterns](./api/patterns/controller-patterns.md)** - RESTful API design and base controllers
- **[CQRS with MediatR](./api/patterns/cqrs-mediatr.md)** - Command/Query separation
- **[Validation Patterns](./api/patterns/validation-patterns.md)** - FluentValidation integration
- **[Error Handling](./api/patterns/error-handling.md)** - Exception filters and Problem Details
- **[OData Patterns](./api/patterns/odata-patterns.md)** - Query, filtering, and pagination
- **[Mapping Patterns](./api/patterns/mapping-patterns.md)** - AutoMapper configuration
- **[Middleware Patterns](./api/patterns/middleware-patterns.md)** - Custom middleware

### Data Access
- **[Entity Framework Core](./api/data/entity-framework.md)** - Best practices, gotchas, PostgreSQL extensions

### Security
- **[Authentication](./api/security/authentication.md)** - JWT + OAuth social providers
- **[Authorization](./api/security/authorization.md)** - Policy-based access control

### Standards
- **[Naming Conventions](./api/standards/naming-conventions.md)** - File, class, method naming and C# style

### Observability
- **[Logging & Monitoring](./api/observability/logging-monitoring.md)** - Serilog, correlation IDs, health checks

### Testing
- **[Testing Strategy](./api/testing/testing-strategy.md)** - Unit, integration, and API testing

### Examples
- **[Controller Template](./api/examples/ControllerTemplate.cs)** - Reference controller
- **[Command Handler Template](./api/examples/CommandHandlerTemplate.cs)** - Reference command handler
- **[Query Handler Template](./api/examples/QueryHandlerTemplate.cs)** - Reference query handler
- **[Validator Template](./api/examples/ValidatorTemplate.cs)** - Reference FluentValidation
- **[Entity Template](./api/examples/EntityTemplate.cs)** - Reference EF Core entity
- **[Repository Template](./api/examples/RepositoryTemplate.cs)** - Reference repository

---

## Tech Stack

| Category | Technology |
|----------|-----------|
| **Framework** | .NET 8 / ASP.NET Core 8 |
| **Language** | C# 12 (nullable enabled, implicit usings) |
| **Architecture** | Clean Architecture + CQRS |
| **Mediator** | MediatR |
| **Validation** | FluentValidation |
| **ORM** | Entity Framework Core 8 (PostgreSQL) |
| **Queries** | OData |
| **Mapping** | AutoMapper |
| **Logging** | Serilog |
| **Testing** | xUnit + Moq + FluentAssertions |
| **API Docs** | Swagger / OpenAPI |

---

## Solution Structure Overview

```
src/
├── MyApp.Api/                    # API entry point
│   ├── Controllers/              # REST controllers
│   ├── Filters/                  # Exception & action filters
│   ├── Middleware/               # Custom middleware
│   └── Program.cs                # Host configuration
│
├── MyApp.Services/               # Business logic (CQRS)
│   ├── Handlers/
│   │   ├── Commands/             # Write operations
│   │   └── Queries/              # Read operations
│   ├── Behaviors/                # MediatR pipeline behaviors
│   └── Services/                 # Domain services
│
├── MyApp.Contracts/              # DTOs & interfaces
│   ├── Commands/                 # Command definitions
│   ├── Queries/                  # Query definitions
│   ├── Dtos/                     # Request/Response DTOs
│   └── Interfaces/               # Service contracts
│
├── MyApp.Data/                   # Persistence
│   ├── Entities/                 # EF Core entities
│   ├── Configurations/           # Entity type configurations
│   ├── Repositories/             # Repository implementations
│   └── Migrations/               # EF migrations
│
└── MyApp.Shared/                 # Cross-cutting concerns
    ├── Extensions/               # Extension methods
    ├── Exceptions/               # Custom exceptions
    └── Constants/                # App-wide constants

tests/
├── MyApp.Tests.Unit/             # Unit tests
├── MyApp.Tests.Integration/      # Integration tests
└── MyApp.Tests.Api/              # API/E2E tests
```

See [Solution Structure](./api/architecture/solution-structure.md) for complete details.

---

## Quick Start

### Common Commands

```bash
# Development
dotnet run --project src/MyApp.Api
dotnet watch --project src/MyApp.Api

# Build
dotnet build
dotnet publish -c Release

# Testing
dotnet test
dotnet test --filter "Category=Unit"
dotnet test --collect:"XPlat Code Coverage"

# Database
dotnet ef migrations add MigrationName --project src/MyApp.Data --startup-project src/MyApp.Api
dotnet ef database update --project src/MyApp.Data --startup-project src/MyApp.Api

# Code Quality
dotnet format
dotnet format --verify-no-changes
```

---

## Development Workflow

### Creating a New Feature

1. **Define contracts** in `MyApp.Contracts`
   - Create DTOs (`CreateProductDto`, `ProductDto`)
   - Create Command/Query records

2. **Add validation** using FluentValidation

3. **Implement handler** in `MyApp.Services`

4. **Add controller endpoint** in `MyApp.Api`

5. **Write tests** for handler and controller

### Working with AI Coding Assistants

Reference relevant docs when prompting:
```
"Implement a product creation endpoint.
Follow patterns in api/patterns/controller-patterns.md and
api/patterns/cqrs-mediatr.md"
```

---

## Quick Reference

### Naming Conventions

```csharp
// Controllers
ProductsController.cs           // Plural, suffix with Controller

// Commands & Queries
CreateProductCommand.cs         // Verb + Entity + Command
GetProductByIdQuery.cs          // Get + Entity + Query

// Handlers
CreateProductCommandHandler.cs  // Command/Query name + Handler

// DTOs
CreateProductDto.cs             // Action + Entity + Dto
ProductDto.cs                   // Entity + Dto (for responses)

// Validators
CreateProductDtoValidator.cs    // DTO name + Validator
```

See [Naming Conventions](./api/standards/naming-conventions.md) for complete rules.

### Code Patterns

```csharp
// Use records for Commands/Queries (immutable)
public record CreateProductCommand(
    CreateProductDto Dto,
    Guid UserId
) : IRequest<ProductDto>;

// Primary constructors for handlers
public class CreateProductCommandHandler(
    IProductRepository repository,
    IMapper mapper
) : IRequestHandler<CreateProductCommand, ProductDto>

// Async all the way with CancellationToken
public async Task<ProductDto> Handle(
    CreateProductCommand request,
    CancellationToken cancellationToken)
{
    await repository.AddAsync(entity, cancellationToken);
}
```

---

## Pre-Commit Checklist

- [ ] All tests pass (`dotnet test`)
- [ ] No build warnings (`dotnet build -warnaserror`)
- [ ] Code formatted (`dotnet format --verify-no-changes`)
- [ ] New features have tests
- [ ] Migrations included if schema changed
- [ ] No secrets in code (use configuration)

---

## External Resources

- [ASP.NET Core Documentation](https://learn.microsoft.com/aspnet/core)
- [Entity Framework Core](https://learn.microsoft.com/ef/core)
- [MediatR Wiki](https://github.com/jbogard/MediatR/wiki)
- [FluentValidation Docs](https://docs.fluentvalidation.net)
- [OData Documentation](https://learn.microsoft.com/odata)
- [Serilog Wiki](https://github.com/serilog/serilog/wiki)
