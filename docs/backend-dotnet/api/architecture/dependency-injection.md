# Dependency Injection

Service registration patterns using Microsoft.Extensions.DependencyInjection.

## Basic Setup

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// Register services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Application services
builder.Services.AddApplicationServices(builder.Configuration);
builder.Services.AddDataServices(builder.Configuration);

var app = builder.Build();
```

---

## Extension Method Pattern

Organize registrations into focused extension methods:

```csharp
// Extensions/ServiceCollectionExtensions.cs
public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddApplicationServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // MediatR
        services.AddMediatR(cfg =>
        {
            cfg.RegisterServicesFromAssembly(typeof(CreateProductCommandHandler).Assembly);
            cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
            cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
        });

        // FluentValidation
        services.AddValidatorsFromAssemblyContaining<CreateProductDtoValidator>();

        // AutoMapper
        services.AddAutoMapper(typeof(ProductMappingProfile).Assembly);

        // Domain services
        services.AddScoped<IProductAccessService, ProductAccessService>();
        services.AddScoped<IProductPersistenceService, ProductPersistenceService>();

        return services;
    }

    public static IServiceCollection AddDataServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // DbContext
        services.AddDbContext<AppDbContext>(options =>
        {
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });

        // Repositories
        services.AddScoped(typeof(IRepository<,>), typeof(Repository<,>));
        services.AddScoped<IProductRepository, ProductRepository>();

        return services;
    }
}
```

---

## Service Lifetimes

| Lifetime | Use Case | Example |
|----------|----------|---------|
| **Transient** | Lightweight, stateless services | Validators, Factories |
| **Scoped** | Per-request services | DbContext, Repositories, Handlers |
| **Singleton** | Shared state, thread-safe services | Configuration, Caching |

```csharp
// Transient - new instance every time
services.AddTransient<IEmailSender, EmailSender>();

// Scoped - one instance per HTTP request
services.AddScoped<IProductRepository, ProductRepository>();
services.AddScoped<IUnitOfWork, UnitOfWork>();

// Singleton - one instance for app lifetime
services.AddSingleton<ICacheService, RedisCacheService>();
services.AddSingleton(TimeProvider.System);
```

### Lifetime Pitfalls

```csharp
// ❌ WRONG: Singleton depending on Scoped
public class CacheService(AppDbContext context) // DbContext is scoped!
{
    // This will throw or cause bugs
}

// ✅ CORRECT: Use IServiceScopeFactory for scoped dependencies in singletons
public class CacheService(IServiceScopeFactory scopeFactory)
{
    public async Task RefreshCacheAsync()
    {
        using var scope = scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        // Use context within this scope
    }
}
```

---

## Keyed Services (.NET 8+)

Register multiple implementations of the same interface:

```csharp
// Registration
services.AddKeyedScoped<INotificationService, EmailNotificationService>("email");
services.AddKeyedScoped<INotificationService, SmsNotificationService>("sms");
services.AddKeyedScoped<INotificationService, PushNotificationService>("push");

// Injection
public class OrderService(
    [FromKeyedServices("email")] INotificationService emailService,
    [FromKeyedServices("sms")] INotificationService smsService)
{
    // Use specific implementations
}
```

---

## Auto-Registration with Scrutor

For convention-based registration (similar to Lamar's scanning):

```bash
dotnet add package Scrutor
```

```csharp
services.Scan(scan => scan
    .FromAssemblyOf<ProductRepository>()
        .AddClasses(classes => classes.AssignableTo(typeof(IRepository<,>)))
        .AsImplementedInterfaces()
        .WithScopedLifetime()

    .FromAssemblyOf<ProductAccessService>()
        .AddClasses(classes => classes.Where(type => type.Name.EndsWith("Service")))
        .AsImplementedInterfaces()
        .WithScopedLifetime()
);
```

---

## Options Pattern for Configuration

Bind configuration sections to strongly-typed classes:

```csharp
// Settings class
public class DatabaseSettings
{
    public const string SectionName = "Database";

    public required string ConnectionString { get; init; }
    public int CommandTimeout { get; init; } = 30;
    public bool EnableSensitiveDataLogging { get; init; } = false;
}

// Registration
services.Configure<DatabaseSettings>(
    configuration.GetSection(DatabaseSettings.SectionName));

// Or with validation
services.AddOptions<DatabaseSettings>()
    .Bind(configuration.GetSection(DatabaseSettings.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();

// Injection
public class SomeService(IOptions<DatabaseSettings> options)
{
    private readonly DatabaseSettings _settings = options.Value;
}
```

---

## Factory Pattern

For runtime service creation:

```csharp
// Interface
public interface IReportGeneratorFactory
{
    IReportGenerator Create(ReportType type);
}

// Implementation
public class ReportGeneratorFactory(IServiceProvider serviceProvider) : IReportGeneratorFactory
{
    public IReportGenerator Create(ReportType type) => type switch
    {
        ReportType.Pdf => serviceProvider.GetRequiredService<PdfReportGenerator>(),
        ReportType.Excel => serviceProvider.GetRequiredService<ExcelReportGenerator>(),
        ReportType.Csv => serviceProvider.GetRequiredService<CsvReportGenerator>(),
        _ => throw new ArgumentOutOfRangeException(nameof(type))
    };
}

// Registration
services.AddScoped<PdfReportGenerator>();
services.AddScoped<ExcelReportGenerator>();
services.AddScoped<CsvReportGenerator>();
services.AddScoped<IReportGeneratorFactory, ReportGeneratorFactory>();
```

---

## Decorator Pattern

Wrap services with additional behavior:

```csharp
// With Scrutor
services.AddScoped<IProductRepository, ProductRepository>();
services.Decorate<IProductRepository, CachedProductRepository>();
services.Decorate<IProductRepository, LoggingProductRepository>();

// Resolution order: LoggingProductRepository → CachedProductRepository → ProductRepository
```

```csharp
// Decorator implementation
public class CachedProductRepository(
    IProductRepository inner,
    ICacheService cache) : IProductRepository
{
    public async Task<Product?> GetByIdAsync(long id, CancellationToken ct)
    {
        var cacheKey = $"product:{id}";
        var cached = await cache.GetAsync<Product>(cacheKey);
        if (cached is not null) return cached;

        var product = await inner.GetByIdAsync(id, ct);
        if (product is not null)
        {
            await cache.SetAsync(cacheKey, product, TimeSpan.FromMinutes(5));
        }
        return product;
    }

    // Delegate other methods to inner
    public Task AddAsync(Product product, CancellationToken ct)
        => inner.AddAsync(product, ct);
}
```

---

## MediatR Registration

```csharp
services.AddMediatR(cfg =>
{
    // Register handlers from assembly
    cfg.RegisterServicesFromAssembly(typeof(CreateProductCommandHandler).Assembly);

    // Pipeline behaviors (order matters - first registered runs first)
    cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
    cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
    cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(TransactionBehavior<,>));
});
```

---

## FluentValidation Registration

```csharp
// Auto-register all validators from assembly
services.AddValidatorsFromAssemblyContaining<CreateProductDtoValidator>();

// Or register individually
services.AddScoped<IValidator<CreateProductDto>, CreateProductDtoValidator>();
```

---

## Testing with DI

```csharp
// Override registrations for testing
public class TestStartup
{
    public static IServiceCollection ConfigureTestServices(IServiceCollection services)
    {
        // Remove real implementations
        var descriptor = services.SingleOrDefault(d =>
            d.ServiceType == typeof(IEmailSender));
        if (descriptor != null) services.Remove(descriptor);

        // Add test doubles
        services.AddScoped<IEmailSender, FakeEmailSender>();

        return services;
    }
}
```

---

## Best Practices

### Do

```csharp
// ✅ Use constructor injection
public class ProductService(IProductRepository repository, IMapper mapper)

// ✅ Depend on abstractions
public class OrderService(IPaymentGateway gateway)  // interface

// ✅ Use primary constructors (C# 12)
public class Handler(IRepo repo, IMapper mapper) : IRequestHandler<Command, Result>

// ✅ Register generic types
services.AddScoped(typeof(IRepository<,>), typeof(Repository<,>));
```

### Don't

```csharp
// ❌ Service locator pattern
public class BadService(IServiceProvider provider)
{
    public void DoWork()
    {
        var repo = provider.GetService<IRepository>(); // Anti-pattern
    }
}

// ❌ Concrete dependencies
public class BadService(ProductRepository repo)  // concrete class

// ❌ Too many dependencies (indicates SRP violation)
public class GodService(
    IRepo1 r1, IRepo2 r2, IRepo3 r3, IRepo4 r4,
    IService1 s1, IService2 s2, IService3 s3)  // Too many!
```

---

## Lamar Alternative

For teams using Lamar (advanced scenarios):

```csharp
// Program.cs
builder.Host.UseLamar((context, registry) =>
{
    registry.Scan(s =>
    {
        s.AssemblyContainingType<ProductRepository>();
        s.WithDefaultConventions();
        s.ConnectImplementationsToTypesClosing(typeof(IRepository<,>));
    });

    registry.For<IProductRepository>().Use<ProductRepository>().Scoped();
});
```

Lamar provides:

- Assembly scanning with conventions
- Better diagnostics (`container.WhatDoIHave()`)
- More advanced decorator support

For most projects, Microsoft.Extensions.DependencyInjection + Scrutor is sufficient.
