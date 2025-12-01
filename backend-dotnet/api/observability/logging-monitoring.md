# Logging & Monitoring

Structured logging with Serilog, correlation IDs, and health checks.

## Setup

```bash
dotnet add package Serilog.AspNetCore
dotnet add package Serilog.Enrichers.Environment
dotnet add package Serilog.Enrichers.Thread
dotnet add package Serilog.Sinks.Console
dotnet add package Serilog.Sinks.Seq          # Optional: for Seq
dotnet add package Serilog.Sinks.Elasticsearch # Optional: for ELK
```

---

## Serilog Configuration

### Program.cs

```csharp
// Program.cs
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .CreateLogger();

try
{
    Log.Information("Starting web application");

    builder.Host.UseSerilog();

    var app = builder.Build();

    app.UseSerilogRequestLogging(options =>
    {
        options.EnrichDiagnosticContext = (diagnosticContext, httpContext) =>
        {
            diagnosticContext.Set("RequestHost", httpContext.Request.Host.Value);
            diagnosticContext.Set("UserAgent", httpContext.Request.Headers.UserAgent.ToString());

            if (httpContext.User.Identity?.IsAuthenticated == true)
            {
                diagnosticContext.Set("UserId", httpContext.User.FindFirstValue(ClaimTypes.NameIdentifier));
            }
        };
    });

    // ... rest of app configuration

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
```

### appsettings.json

```json
{
  "Serilog": {
    "Using": ["Serilog.Sinks.Console", "Serilog.Sinks.Seq"],
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft.AspNetCore": "Warning",
        "Microsoft.EntityFrameworkCore": "Warning",
        "Microsoft.EntityFrameworkCore.Database.Command": "Warning",
        "System": "Warning"
      }
    },
    "WriteTo": [
      {
        "Name": "Console",
        "Args": {
          "outputTemplate": "{Timestamp:yyyy-MM-dd HH:mm:ss.fff} [{Level:u3}] [{CorrelationId}] {Message:lj}{NewLine}{Exception}"
        }
      },
      {
        "Name": "Seq",
        "Args": {
          "serverUrl": "http://localhost:5341"
        }
      }
    ],
    "Enrich": ["FromLogContext", "WithMachineName", "WithThreadId"],
    "Properties": {
      "Application": "MyApp.Api"
    }
  }
}
```

### Development vs Production

```json
// appsettings.Development.json
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Debug",
      "Override": {
        "Microsoft.EntityFrameworkCore.Database.Command": "Information"
      }
    }
  }
}

// appsettings.Production.json
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information"
    },
    "WriteTo": [
      {
        "Name": "Elasticsearch",
        "Args": {
          "nodeUris": "http://elasticsearch:9200",
          "indexFormat": "myapp-{0:yyyy.MM.dd}"
        }
      }
    ]
  }
}
```

---

## Correlation ID

Track requests across services:

```csharp
// Api/Middleware/CorrelationIdMiddleware.cs
public class CorrelationIdMiddleware(RequestDelegate next)
{
    private const string CorrelationIdHeader = "X-Correlation-Id";

    public async Task InvokeAsync(HttpContext context)
    {
        var correlationId = GetOrCreateCorrelationId(context);

        // Add to response headers
        context.Response.OnStarting(() =>
        {
            context.Response.Headers.TryAdd(CorrelationIdHeader, correlationId);
            return Task.CompletedTask;
        });

        // Add to Serilog LogContext
        using (LogContext.PushProperty("CorrelationId", correlationId))
        {
            await next(context);
        }
    }

    private static string GetOrCreateCorrelationId(HttpContext context)
    {
        if (context.Request.Headers.TryGetValue(CorrelationIdHeader, out var correlationId)
            && !string.IsNullOrWhiteSpace(correlationId))
        {
            return correlationId.ToString();
        }

        return Guid.NewGuid().ToString();
    }
}

// Registration
app.UseCorrelationId();  // Before UseSerilogRequestLogging
app.UseSerilogRequestLogging();
```

---

## Structured Logging Best Practices

### Use Message Templates

```csharp
// ✅ Good - structured properties
logger.LogInformation(
    "Processing order {OrderId} for customer {CustomerId}",
    order.Id,
    order.CustomerId);

// ❌ Bad - string interpolation (not searchable)
logger.LogInformation($"Processing order {order.Id} for customer {order.CustomerId}");
```

### Include Context

```csharp
// ✅ Include relevant context
logger.LogError(
    exception,
    "Failed to process payment for order {OrderId}. Amount: {Amount}, Gateway: {Gateway}",
    orderId,
    amount,
    gatewayName);

// ✅ Use scopes for related operations
using (logger.BeginScope(new Dictionary<string, object>
{
    ["OrderId"] = orderId,
    ["CustomerId"] = customerId
}))
{
    logger.LogInformation("Starting order processing");
    // All logs in this scope include OrderId and CustomerId
    logger.LogInformation("Validating items");
    logger.LogInformation("Calculating totals");
}
```

### Log Levels

| Level | Use Case | Example |
|-------|----------|---------|
| Trace | Detailed debugging | Variable values in loops |
| Debug | Development debugging | Method entry/exit |
| Information | Normal operation | Request completed, user logged in |
| Warning | Recoverable issues | Retry attempt, deprecated API used |
| Error | Failures requiring attention | Exception caught, operation failed |
| Critical | System-level failures | Database down, out of memory |

```csharp
// Trace - very detailed
logger.LogTrace("Entering method {Method} with params {@Params}", nameof(Process), parameters);

// Debug - diagnostic info
logger.LogDebug("Cache miss for key {CacheKey}", cacheKey);

// Information - normal operations
logger.LogInformation("User {UserId} logged in successfully", userId);

// Warning - potential issues
logger.LogWarning("Rate limit approaching for client {ClientId}. Count: {Count}", clientId, count);

// Error - failures
logger.LogError(exception, "Failed to send email to {Email}", recipientEmail);

// Critical - system failures
logger.LogCritical(exception, "Database connection failed. Shutting down.");
```

---

## Logging in Different Layers

### Controllers

```csharp
public class ProductsController(
    IMediator mediator,
    ILogger<ProductsController> logger
) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<ProductDto>> Create(
        CreateProductDto dto,
        CancellationToken cancellationToken)
    {
        logger.LogInformation(
            "Creating product with name {ProductName}",
            dto.Name);

        var command = new CreateProductCommand(dto, UserId);
        var result = await mediator.Send(command, cancellationToken);

        logger.LogInformation(
            "Product created with ID {ProductId}",
            result.Id);

        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }
}
```

### Handlers

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
        logger.LogDebug(
            "Handling CreateProductCommand for user {UserId}",
            request.UserId);

        var entity = mapper.Map<ProductEntity>(request.Dto);

        try
        {
            await repository.AddAsync(entity, cancellationToken);

            logger.LogInformation(
                "Product {ProductId} created by user {UserId}",
                entity.Id,
                request.UserId);
        }
        catch (Exception ex)
        {
            logger.LogError(
                ex,
                "Failed to create product {ProductName} for user {UserId}",
                request.Dto.Name,
                request.UserId);
            throw;
        }

        return mapper.Map<ProductDto>(entity);
    }
}
```

### Logging Behavior

```csharp
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
        var requestId = Guid.NewGuid().ToString()[..8];

        logger.LogInformation(
            "[{RequestId}] Handling {RequestName}",
            requestId,
            requestName);

        var stopwatch = Stopwatch.StartNew();

        try
        {
            var response = await next();
            stopwatch.Stop();

            logger.LogInformation(
                "[{RequestId}] Handled {RequestName} in {ElapsedMs}ms",
                requestId,
                requestName,
                stopwatch.ElapsedMilliseconds);

            return response;
        }
        catch (Exception ex)
        {
            stopwatch.Stop();

            logger.LogError(
                ex,
                "[{RequestId}] Failed {RequestName} after {ElapsedMs}ms",
                requestId,
                requestName,
                stopwatch.ElapsedMilliseconds);

            throw;
        }
    }
}
```

---

## Health Checks

### Setup

```csharp
// Program.cs
builder.Services.AddHealthChecks()
    .AddNpgSql(
        builder.Configuration.GetConnectionString("DefaultConnection")!,
        name: "database",
        tags: ["ready"])
    .AddRedis(
        builder.Configuration.GetConnectionString("Redis")!,
        name: "redis",
        tags: ["ready"])
    .AddUrlGroup(
        new Uri(builder.Configuration["ExternalServices:PaymentApi"]!),
        name: "payment-api",
        tags: ["ready"]);

// Map endpoints
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false  // No checks, just confirm app is running
});

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),
    ResponseWriter = WriteHealthCheckResponse
});

// Custom response writer
static async Task WriteHealthCheckResponse(HttpContext context, HealthReport report)
{
    context.Response.ContentType = "application/json";

    var response = new
    {
        status = report.Status.ToString(),
        checks = report.Entries.Select(e => new
        {
            name = e.Key,
            status = e.Value.Status.ToString(),
            duration = e.Value.Duration.TotalMilliseconds,
            exception = e.Value.Exception?.Message
        })
    };

    await context.Response.WriteAsJsonAsync(response);
}
```

### Custom Health Check

```csharp
public class ExternalApiHealthCheck(
    IHttpClientFactory httpClientFactory,
    ILogger<ExternalApiHealthCheck> logger
) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var client = httpClientFactory.CreateClient("ExternalApi");
            var response = await client.GetAsync("/health", cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                return HealthCheckResult.Healthy("External API is responding");
            }

            return HealthCheckResult.Degraded(
                $"External API returned {response.StatusCode}");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "External API health check failed");

            return HealthCheckResult.Unhealthy(
                "External API is not responding",
                ex);
        }
    }
}

// Registration
builder.Services.AddHealthChecks()
    .AddCheck<ExternalApiHealthCheck>("external-api", tags: ["ready"]);
```

### Health Check Response

```http
GET /health/ready

{
  "status": "Healthy",
  "checks": [
    {
      "name": "database",
      "status": "Healthy",
      "duration": 15.2,
      "exception": null
    },
    {
      "name": "redis",
      "status": "Healthy",
      "duration": 5.1,
      "exception": null
    },
    {
      "name": "payment-api",
      "status": "Degraded",
      "duration": 250.3,
      "exception": "High latency detected"
    }
  ]
}
```

---

## Performance Logging

### Slow Query Detection

```csharp
// DbContext configuration
builder.Services.AddDbContext<AppDbContext>((sp, options) =>
{
    options.UseNpgsql(connectionString);

    options.LogTo(
        message =>
        {
            var logger = sp.GetRequiredService<ILogger<AppDbContext>>();
            logger.LogWarning("Slow query detected: {Query}", message);
        },
        (eventId, level) => eventId.Id == RelationalEventId.CommandExecuted.Id,
        DbContextLoggerOptions.SingleLine);
});
```

### Custom Performance Logger

```csharp
public class PerformanceLoggingBehavior<TRequest, TResponse>(
    ILogger<PerformanceLoggingBehavior<TRequest, TResponse>> logger
) : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    private const int SlowRequestThresholdMs = 500;

    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        var stopwatch = Stopwatch.StartNew();

        var response = await next();

        stopwatch.Stop();

        if (stopwatch.ElapsedMilliseconds > SlowRequestThresholdMs)
        {
            logger.LogWarning(
                "Slow request detected: {RequestName} took {ElapsedMs}ms",
                typeof(TRequest).Name,
                stopwatch.ElapsedMilliseconds);
        }

        return response;
    }
}
```

---

## Sensitive Data

### Redact Sensitive Information

```csharp
// ❌ Bad - logs sensitive data
logger.LogInformation("User login: Email={Email}, Password={Password}", email, password);

// ✅ Good - redact sensitive fields
logger.LogInformation("User login attempt for {Email}", email);

// ✅ Use destructuring carefully
logger.LogInformation("Processing order {@Order}", new
{
    order.Id,
    order.Total,
    // Don't include: CustomerEmail, PaymentDetails
});
```

### Configure Serilog Destructuring

```csharp
Log.Logger = new LoggerConfiguration()
    .Destructure.ByTransforming<UserEntity>(u => new
    {
        u.Id,
        u.Email,
        // Exclude: PasswordHash, SecurityStamp
    })
    .CreateLogger();
```

---

## Best Practices

### Do

```csharp
// ✅ Use structured logging
logger.LogInformation("Order {OrderId} processed", orderId);

// ✅ Include correlation ID
using (LogContext.PushProperty("CorrelationId", correlationId))

// ✅ Log at appropriate levels
logger.LogDebug("..."); // Development only
logger.LogError(exception, "..."); // Include exception

// ✅ Use scopes for context
using (logger.BeginScope(new { OrderId = orderId }))
```

### Don't

```csharp
// ❌ String interpolation
logger.LogInformation($"Order {orderId} processed");

// ❌ Log sensitive data
logger.LogInformation("Password: {Password}", password);

// ❌ Catch and log without rethrowing
catch (Exception ex)
{
    logger.LogError(ex, "Error");
    // Missing: throw;
}

// ❌ Overlogging in loops
foreach (var item in items)
{
    logger.LogInformation("Processing {Item}", item);  // Too noisy
}
```
