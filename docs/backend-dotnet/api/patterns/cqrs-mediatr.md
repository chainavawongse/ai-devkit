# CQRS with MediatR

Command/Query Responsibility Segregation pattern using MediatR.

## Overview

**CQRS separates reads (Queries) from writes (Commands):**

- **Commands** - Change state, return result or nothing
- **Queries** - Read state, never modify data

**MediatR provides:**

- Decoupling between controllers and business logic
- Pipeline behaviors for cross-cutting concerns
- Simple in-process messaging

---

## Commands

Commands represent intentions to change state.

### Command Definition

```csharp
// Contracts/Commands/CreateProductCommand.cs
public record CreateProductCommand(
    CreateProductDto Dto,
    Guid UserId
) : IRequest<ProductDto>;

// With validation marker
public record CreateProductCommand(
    CreateProductDto Dto,
    Guid UserId
) : IRequest<ProductDto>, IValidatable;

// No return value
public record DeleteProductCommand(
    long Id,
    Guid UserId
) : IRequest;
```

### Command Handler

```csharp
// Services/Handlers/Commands/CreateProductCommandHandler.cs
public class CreateProductCommandHandler(
    IProductRepository repository,
    IMapper mapper,
    IEventPublisher eventPublisher,
    ILogger<CreateProductCommandHandler> logger
) : IRequestHandler<CreateProductCommand, ProductDto>
{
    public async Task<ProductDto> Handle(
        CreateProductCommand request,
        CancellationToken cancellationToken)
    {
        logger.LogInformation(
            "Creating product {Name} for user {UserId}",
            request.Dto.Name,
            request.UserId);

        // Map DTO to entity
        var entity = mapper.Map<ProductEntity>(request.Dto);
        entity.CreatedBy = request.UserId;
        entity.CreatedAt = DateTime.UtcNow;

        // Persist
        await repository.AddAsync(entity, cancellationToken);

        // Publish domain event
        await eventPublisher.PublishAsync(
            new ProductCreatedEvent(entity.Id, entity.Name),
            cancellationToken);

        // Return mapped result
        return mapper.Map<ProductDto>(entity);
    }
}
```

### Command Without Return Value

```csharp
public class DeleteProductCommandHandler(
    IProductRepository repository,
    ILogger<DeleteProductCommandHandler> logger
) : IRequestHandler<DeleteProductCommand>
{
    public async Task Handle(
        DeleteProductCommand request,
        CancellationToken cancellationToken)
    {
        var entity = await repository.GetByIdAsync(request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Product), request.Id);

        await repository.DeleteAsync(entity, cancellationToken);

        logger.LogInformation(
            "Product {Id} deleted by user {UserId}",
            request.Id,
            request.UserId);
    }
}
```

---

## Queries

Queries read data without side effects.

### Query Definition

```csharp
// Contracts/Queries/GetProductByIdQuery.cs
public record GetProductByIdQuery(long Id) : IRequest<ProductDto>;

// With filtering
public record GetProductsQuery(
    string? SearchTerm = null,
    ProductStatus? Status = null,
    int Page = 1,
    int PageSize = 20
) : IRequest<PaginatedResult<ProductDto>>;
```

### Query Handler

```csharp
// Services/Handlers/Queries/GetProductByIdQueryHandler.cs
public class GetProductByIdQueryHandler(
    IProductRepository repository,
    IMapper mapper
) : IRequestHandler<GetProductByIdQuery, ProductDto>
{
    public async Task<ProductDto> Handle(
        GetProductByIdQuery request,
        CancellationToken cancellationToken)
    {
        var entity = await repository.GetByIdAsync(request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Product), request.Id);

        return mapper.Map<ProductDto>(entity);
    }
}
```

### Query Handler with Pagination

```csharp
public class GetProductsQueryHandler(
    IProductRepository repository,
    IMapper mapper
) : IRequestHandler<GetProductsQuery, PaginatedResult<ProductDto>>
{
    public async Task<PaginatedResult<ProductDto>> Handle(
        GetProductsQuery request,
        CancellationToken cancellationToken)
    {
        var query = repository.GetQueryable();

        // Apply filters
        if (!string.IsNullOrWhiteSpace(request.SearchTerm))
        {
            query = query.Where(p =>
                p.Name.Contains(request.SearchTerm) ||
                p.Description.Contains(request.SearchTerm));
        }

        if (request.Status.HasValue)
        {
            query = query.Where(p => p.Status == request.Status.Value);
        }

        // Get total count
        var totalCount = await query.CountAsync(cancellationToken);

        // Apply pagination
        var items = await query
            .OrderBy(p => p.Name)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync(cancellationToken);

        return new PaginatedResult<ProductDto>
        {
            Items = mapper.Map<List<ProductDto>>(items),
            TotalCount = totalCount,
            Page = request.Page,
            PageSize = request.PageSize
        };
    }
}
```

---

## Pipeline Behaviors

Cross-cutting concerns applied to all requests.

### Validation Behavior

```csharp
// Services/Behaviors/ValidationBehavior.cs
public class ValidationBehavior<TRequest, TResponse>(
    IEnumerable<IValidator<TRequest>> validators
) : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        if (!validators.Any())
            return await next();

        var context = new ValidationContext<TRequest>(request);

        var validationResults = await Task.WhenAll(
            validators.Select(v => v.ValidateAsync(context, cancellationToken)));

        var failures = validationResults
            .SelectMany(r => r.Errors)
            .Where(f => f is not null)
            .ToList();

        if (failures.Count > 0)
            throw new ValidationException(failures);

        return await next();
    }
}
```

### Logging Behavior

```csharp
// Services/Behaviors/LoggingBehavior.cs
public class LoggingBehavior<TRequest, TResponse>(
    ILogger<LoggingBehavior<TRequest, TResponse>> logger
) : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        var requestName = typeof(TRequest).Name;

        logger.LogInformation(
            "Handling {RequestName}: {@Request}",
            requestName,
            request);

        var stopwatch = Stopwatch.StartNew();

        try
        {
            var response = await next();
            stopwatch.Stop();

            logger.LogInformation(
                "Handled {RequestName} in {ElapsedMs}ms",
                requestName,
                stopwatch.ElapsedMilliseconds);

            return response;
        }
        catch (Exception ex)
        {
            stopwatch.Stop();

            logger.LogError(
                ex,
                "Error handling {RequestName} after {ElapsedMs}ms",
                requestName,
                stopwatch.ElapsedMilliseconds);

            throw;
        }
    }
}
```

### Transaction Behavior

```csharp
// Services/Behaviors/TransactionBehavior.cs
public class TransactionBehavior<TRequest, TResponse>(
    AppDbContext context,
    ILogger<TransactionBehavior<TRequest, TResponse>> logger
) : IPipelineBehavior<TRequest, TResponse>
    where TRequest : ITransactional  // Marker interface
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        if (context.Database.CurrentTransaction is not null)
            return await next();

        await using var transaction = await context.Database
            .BeginTransactionAsync(cancellationToken);

        try
        {
            var response = await next();
            await transaction.CommitAsync(cancellationToken);
            return response;
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }
}
```

---

## Registration

```csharp
// Program.cs or ServiceCollectionExtensions.cs
services.AddMediatR(cfg =>
{
    // Register handlers from assembly
    cfg.RegisterServicesFromAssembly(typeof(CreateProductCommandHandler).Assembly);

    // Pipeline behaviors - order matters
    cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
    cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
    cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(TransactionBehavior<,>));
});
```

---

## Command Factory Pattern

For complex command creation, use factories:

```csharp
// Contracts/Interfaces/IProductCommandFactory.cs
public interface IProductCommandFactory
{
    CreateProductCommand CreateAddCommand(CreateProductDto dto, Guid userId);
    UpdateProductCommand CreateUpdateCommand(long id, UpdateProductDto dto, Guid userId);
}

// Services/Factories/ProductCommandFactory.cs
public class ProductCommandFactory(
    IValidator<CreateProductDto> createValidator
) : IProductCommandFactory
{
    public CreateProductCommand CreateAddCommand(CreateProductDto dto, Guid userId)
    {
        // Additional preprocessing if needed
        return new CreateProductCommand(dto, userId);
    }

    public UpdateProductCommand CreateUpdateCommand(
        long id,
        UpdateProductDto dto,
        Guid userId)
    {
        return new UpdateProductCommand(id, dto, userId);
    }
}
```

---

## Notifications (Events)

For publishing domain events to multiple handlers:

```csharp
// Contracts/Events/ProductCreatedEvent.cs
public record ProductCreatedEvent(long ProductId, string Name) : INotification;

// Handler 1: Send email
public class ProductCreatedEmailHandler(
    IEmailService emailService
) : INotificationHandler<ProductCreatedEvent>
{
    public async Task Handle(
        ProductCreatedEvent notification,
        CancellationToken cancellationToken)
    {
        await emailService.SendProductCreatedEmailAsync(
            notification.ProductId,
            notification.Name,
            cancellationToken);
    }
}

// Handler 2: Update search index
public class ProductCreatedSearchIndexHandler(
    ISearchIndexService searchService
) : INotificationHandler<ProductCreatedEvent>
{
    public async Task Handle(
        ProductCreatedEvent notification,
        CancellationToken cancellationToken)
    {
        await searchService.IndexProductAsync(
            notification.ProductId,
            cancellationToken);
    }
}

// Publishing
await mediator.Publish(new ProductCreatedEvent(entity.Id, entity.Name), ct);
```

---

## Testing Handlers

```csharp
public class CreateProductCommandHandlerTests
{
    private readonly Mock<IProductRepository> _repositoryMock = new();
    private readonly Mock<IMapper> _mapperMock = new();
    private readonly Mock<IEventPublisher> _eventPublisherMock = new();
    private readonly CreateProductCommandHandler _handler;

    public CreateProductCommandHandlerTests()
    {
        _handler = new CreateProductCommandHandler(
            _repositoryMock.Object,
            _mapperMock.Object,
            _eventPublisherMock.Object,
            Mock.Of<ILogger<CreateProductCommandHandler>>());
    }

    [Fact]
    public async Task Handle_ValidCommand_CreatesProductAndPublishesEvent()
    {
        // Arrange
        var dto = new CreateProductDto { Name = "Test", Price = 10.00m };
        var command = new CreateProductCommand(dto, Guid.NewGuid());
        var entity = new ProductEntity { Id = 1, Name = "Test" };
        var resultDto = new ProductDto { Id = 1, Name = "Test" };

        _mapperMock
            .Setup(m => m.Map<ProductEntity>(dto))
            .Returns(entity);
        _mapperMock
            .Setup(m => m.Map<ProductDto>(entity))
            .Returns(resultDto);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.Should().BeEquivalentTo(resultDto);

        _repositoryMock.Verify(
            r => r.AddAsync(entity, It.IsAny<CancellationToken>()),
            Times.Once);

        _eventPublisherMock.Verify(
            e => e.PublishAsync(
                It.Is<ProductCreatedEvent>(evt => evt.ProductId == entity.Id),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }
}
```

---

## Folder Organization

```
Services/
├── Handlers/
│   ├── Commands/
│   │   ├── CreateProductCommandHandler.cs
│   │   ├── UpdateProductCommandHandler.cs
│   │   └── DeleteProductCommandHandler.cs
│   └── Queries/
│       ├── GetProductByIdQueryHandler.cs
│       └── GetProductsQueryHandler.cs
├── Behaviors/
│   ├── ValidationBehavior.cs
│   ├── LoggingBehavior.cs
│   └── TransactionBehavior.cs
└── Notifications/
    ├── ProductCreatedEmailHandler.cs
    └── ProductCreatedSearchIndexHandler.cs

Contracts/
├── Commands/
│   ├── CreateProductCommand.cs
│   ├── UpdateProductCommand.cs
│   └── DeleteProductCommand.cs
├── Queries/
│   ├── GetProductByIdQuery.cs
│   └── GetProductsQuery.cs
└── Events/
    └── ProductCreatedEvent.cs
```

---

## Best Practices

### Do

```csharp
// ✅ Use records for immutable commands/queries
public record CreateProductCommand(CreateProductDto Dto, Guid UserId) : IRequest<ProductDto>;

// ✅ Use CancellationToken in handlers
public async Task<ProductDto> Handle(Command cmd, CancellationToken ct)

// ✅ Single responsibility - one handler per command/query
public class CreateProductCommandHandler : IRequestHandler<CreateProductCommand, ProductDto>

// ✅ Use pipeline behaviors for cross-cutting concerns
cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));

// ✅ Throw domain exceptions in handlers
throw new EntityNotFoundException(nameof(Product), request.Id);
```

### Don't

```csharp
// ❌ Mutable commands
public class CreateProductCommand : IRequest<ProductDto>
{
    public string Name { get; set; }  // Should be init
}

// ❌ Multiple responsibilities in one handler
public class ProductHandler :
    IRequestHandler<CreateProductCommand>,
    IRequestHandler<UpdateProductCommand>,
    IRequestHandler<DeleteProductCommand>

// ❌ Returning entities instead of DTOs
public record GetProductQuery(long Id) : IRequest<ProductEntity>;  // Bad

// ❌ Side effects in query handlers
public class GetProductQueryHandler
{
    public async Task<ProductDto> Handle(...)
    {
        await _repository.UpdateViewCountAsync();  // Side effect in query!
    }
}
```
