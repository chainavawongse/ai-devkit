# Error Handling

Exception filters, Problem Details, and centralized error management.

## Exception Hierarchy

```csharp
// Shared/Exceptions/

// Base exception
public abstract class AppException : Exception
{
    public abstract int StatusCode { get; }
    public abstract string ErrorCode { get; }

    protected AppException(string message) : base(message) { }
    protected AppException(string message, Exception inner) : base(message, inner) { }
}

// 404 - Not Found
public class EntityNotFoundException : AppException
{
    public override int StatusCode => StatusCodes.Status404NotFound;
    public override string ErrorCode => "ENTITY_NOT_FOUND";

    public string EntityType { get; }
    public object EntityId { get; }

    public EntityNotFoundException(string entityType, object entityId)
        : base($"{entityType} with ID '{entityId}' was not found.")
    {
        EntityType = entityType;
        EntityId = entityId;
    }
}

// 400 - Validation
public class ValidationException : AppException
{
    public override int StatusCode => StatusCodes.Status400BadRequest;
    public override string ErrorCode => "VALIDATION_FAILED";

    public IDictionary<string, string[]> Errors { get; }

    public ValidationException(IDictionary<string, string[]> errors)
        : base("One or more validation errors occurred.")
    {
        Errors = errors;
    }

    public ValidationException(IEnumerable<ValidationFailure> failures)
        : base("One or more validation errors occurred.")
    {
        Errors = failures
            .GroupBy(f => f.PropertyName, f => f.ErrorMessage)
            .ToDictionary(g => g.Key, g => g.ToArray());
    }
}

// 409 - Conflict
public class ConflictException : AppException
{
    public override int StatusCode => StatusCodes.Status409Conflict;
    public override string ErrorCode => "CONFLICT";

    public ConflictException(string message) : base(message) { }
}

// 422 - Unprocessable Entity (business rule violation)
public class BusinessRuleException : AppException
{
    public override int StatusCode => StatusCodes.Status422UnprocessableEntity;
    public override string ErrorCode => "BUSINESS_RULE_VIOLATION";

    public BusinessRuleException(string message) : base(message) { }
}

// 403 - Forbidden
public class ForbiddenException : AppException
{
    public override int StatusCode => StatusCodes.Status403Forbidden;
    public override string ErrorCode => "FORBIDDEN";

    public ForbiddenException(string message = "You do not have permission to perform this action.")
        : base(message) { }
}
```

---

## Exception Filter

```csharp
// Api/Filters/ApiExceptionFilter.cs
public class ApiExceptionFilter(
    ILogger<ApiExceptionFilter> logger,
    IHostEnvironment environment
) : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        var exception = context.Exception;

        logger.LogError(
            exception,
            "Unhandled exception: {Message}",
            exception.Message);

        var problemDetails = exception switch
        {
            ValidationException validationEx => CreateValidationProblem(validationEx),
            EntityNotFoundException notFoundEx => CreateNotFoundProblem(notFoundEx),
            ConflictException conflictEx => CreateConflictProblem(conflictEx),
            BusinessRuleException businessEx => CreateBusinessRuleProblem(businessEx),
            ForbiddenException forbiddenEx => CreateForbiddenProblem(forbiddenEx),
            UnauthorizedAccessException => CreateUnauthorizedProblem(),
            _ => CreateInternalErrorProblem(exception)
        };

        context.Result = new ObjectResult(problemDetails)
        {
            StatusCode = problemDetails.Status
        };

        context.ExceptionHandled = true;
    }

    private ValidationProblemDetails CreateValidationProblem(ValidationException ex)
    {
        return new ValidationProblemDetails(ex.Errors)
        {
            Type = "https://tools.ietf.org/html/rfc7231#section-6.5.1",
            Title = "Validation Failed",
            Status = StatusCodes.Status400BadRequest,
            Detail = ex.Message,
            Instance = GetRequestPath()
        };
    }

    private ProblemDetails CreateNotFoundProblem(EntityNotFoundException ex)
    {
        return new ProblemDetails
        {
            Type = "https://tools.ietf.org/html/rfc7231#section-6.5.4",
            Title = "Resource Not Found",
            Status = StatusCodes.Status404NotFound,
            Detail = ex.Message,
            Instance = GetRequestPath(),
            Extensions =
            {
                ["entityType"] = ex.EntityType,
                ["entityId"] = ex.EntityId
            }
        };
    }

    private ProblemDetails CreateConflictProblem(ConflictException ex)
    {
        return new ProblemDetails
        {
            Type = "https://tools.ietf.org/html/rfc7231#section-6.5.8",
            Title = "Conflict",
            Status = StatusCodes.Status409Conflict,
            Detail = ex.Message,
            Instance = GetRequestPath()
        };
    }

    private ProblemDetails CreateBusinessRuleProblem(BusinessRuleException ex)
    {
        return new ProblemDetails
        {
            Type = "https://tools.ietf.org/html/rfc4918#section-11.2",
            Title = "Business Rule Violation",
            Status = StatusCodes.Status422UnprocessableEntity,
            Detail = ex.Message,
            Instance = GetRequestPath()
        };
    }

    private ProblemDetails CreateForbiddenProblem(ForbiddenException ex)
    {
        return new ProblemDetails
        {
            Type = "https://tools.ietf.org/html/rfc7231#section-6.5.3",
            Title = "Forbidden",
            Status = StatusCodes.Status403Forbidden,
            Detail = ex.Message,
            Instance = GetRequestPath()
        };
    }

    private ProblemDetails CreateUnauthorizedProblem()
    {
        return new ProblemDetails
        {
            Type = "https://tools.ietf.org/html/rfc7235#section-3.1",
            Title = "Unauthorized",
            Status = StatusCodes.Status401Unauthorized,
            Detail = "Authentication is required to access this resource.",
            Instance = GetRequestPath()
        };
    }

    private ProblemDetails CreateInternalErrorProblem(Exception ex)
    {
        var problemDetails = new ProblemDetails
        {
            Type = "https://tools.ietf.org/html/rfc7231#section-6.6.1",
            Title = "Internal Server Error",
            Status = StatusCodes.Status500InternalServerError,
            Detail = "An unexpected error occurred. Please try again later.",
            Instance = GetRequestPath()
        };

        // Include stack trace in development
        if (environment.IsDevelopment())
        {
            problemDetails.Extensions["exception"] = ex.ToString();
        }

        return problemDetails;
    }

    private string GetRequestPath()
    {
        // Implementation to get current request path
        return string.Empty;
    }
}
```

---

## Registration

```csharp
// Program.cs
builder.Services.AddControllers(options =>
{
    options.Filters.Add<ApiExceptionFilter>();
});

// Or per-controller
[ServiceFilter(typeof(ApiExceptionFilter))]
public class ProductsController : ControllerBase { }
```

---

## Problem Details Format

Following RFC 7807 - Problem Details for HTTP APIs:

```json
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.4",
  "title": "Resource Not Found",
  "status": 404,
  "detail": "Product with ID '123' was not found.",
  "instance": "/api/products/123",
  "entityType": "Product",
  "entityId": "123"
}
```

### Validation Error Response

```json
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.1",
  "title": "Validation Failed",
  "status": 400,
  "detail": "One or more validation errors occurred.",
  "instance": "/api/products",
  "errors": {
    "Name": ["Product name is required"],
    "Price": ["Price must be greater than zero", "Price cannot exceed 1,000,000"],
    "CategoryId": ["Category does not exist"]
  }
}
```

---

## Using Exceptions in Handlers

```csharp
public class GetProductByIdQueryHandler(
    IProductRepository repository,
    IMapper mapper
) : IRequestHandler<GetProductByIdQuery, ProductDto>
{
    public async Task<ProductDto> Handle(
        GetProductByIdQuery request,
        CancellationToken cancellationToken)
    {
        var product = await repository.GetByIdAsync(request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Product), request.Id);

        return mapper.Map<ProductDto>(product);
    }
}

public class UpdateProductCommandHandler(
    IProductRepository repository,
    IMapper mapper
) : IRequestHandler<UpdateProductCommand, ProductDto>
{
    public async Task<ProductDto> Handle(
        UpdateProductCommand request,
        CancellationToken cancellationToken)
    {
        var product = await repository.GetByIdAsync(request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Product), request.Id);

        // Check for conflicts
        if (request.Dto.Sku != product.Sku)
        {
            var existingSku = await repository.GetBySkuAsync(request.Dto.Sku, cancellationToken);
            if (existingSku is not null)
            {
                throw new ConflictException($"Product with SKU '{request.Dto.Sku}' already exists.");
            }
        }

        // Business rule validation
        if (product.Status == ProductStatus.Discontinued)
        {
            throw new BusinessRuleException("Cannot update a discontinued product.");
        }

        mapper.Map(request.Dto, product);
        await repository.UpdateAsync(product, cancellationToken);

        return mapper.Map<ProductDto>(product);
    }
}
```

---

## Global Exception Handling Middleware

Alternative to exception filter for catching all exceptions:

```csharp
// Api/Middleware/ExceptionHandlingMiddleware.cs
public class ExceptionHandlingMiddleware(
    RequestDelegate next,
    ILogger<ExceptionHandlingMiddleware> logger,
    IHostEnvironment environment)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        logger.LogError(exception, "Unhandled exception: {Message}", exception.Message);

        var (statusCode, problemDetails) = exception switch
        {
            ValidationException ex => (400, CreateValidationProblem(ex)),
            EntityNotFoundException ex => (404, CreateProblem(ex)),
            ConflictException ex => (409, CreateProblem(ex)),
            BusinessRuleException ex => (422, CreateProblem(ex)),
            ForbiddenException ex => (403, CreateProblem(ex)),
            _ => (500, CreateInternalProblem(exception))
        };

        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/problem+json";

        await context.Response.WriteAsJsonAsync(problemDetails);
    }

    private ProblemDetails CreateProblem(AppException ex)
    {
        return new ProblemDetails
        {
            Title = ex.ErrorCode,
            Status = ex.StatusCode,
            Detail = ex.Message
        };
    }

    private object CreateValidationProblem(ValidationException ex)
    {
        return new ValidationProblemDetails(ex.Errors)
        {
            Title = "Validation Failed",
            Status = 400
        };
    }

    private ProblemDetails CreateInternalProblem(Exception ex)
    {
        var problem = new ProblemDetails
        {
            Title = "Internal Server Error",
            Status = 500,
            Detail = "An unexpected error occurred."
        };

        if (environment.IsDevelopment())
        {
            problem.Extensions["exception"] = ex.ToString();
        }

        return problem;
    }
}

// Registration in Program.cs
app.UseMiddleware<ExceptionHandlingMiddleware>();
```

---

## Specific Exception Types

### Database Exceptions

```csharp
public class DatabaseException : AppException
{
    public override int StatusCode => StatusCodes.Status500InternalServerError;
    public override string ErrorCode => "DATABASE_ERROR";

    public DatabaseException(string message, Exception inner)
        : base(message, inner) { }
}

// Usage in repository
try
{
    await context.SaveChangesAsync(cancellationToken);
}
catch (DbUpdateException ex)
{
    throw new DatabaseException("Failed to save changes to the database.", ex);
}
```

### External Service Exceptions

```csharp
public class ExternalServiceException : AppException
{
    public override int StatusCode => StatusCodes.Status502BadGateway;
    public override string ErrorCode => "EXTERNAL_SERVICE_ERROR";

    public string ServiceName { get; }

    public ExternalServiceException(string serviceName, string message)
        : base($"{serviceName}: {message}")
    {
        ServiceName = serviceName;
    }
}

// Usage
throw new ExternalServiceException("PaymentGateway", "Payment processing failed.");
```

---

## Correlation ID for Tracking

Include correlation ID in error responses for debugging:

```csharp
public class ApiExceptionFilter(
    ILogger<ApiExceptionFilter> logger,
    IHttpContextAccessor httpContextAccessor
) : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        var correlationId = httpContextAccessor.HttpContext?
            .Request.Headers["X-Correlation-Id"].FirstOrDefault()
            ?? Guid.NewGuid().ToString();

        var problemDetails = CreateProblemDetails(context.Exception);
        problemDetails.Extensions["correlationId"] = correlationId;

        logger.LogError(
            context.Exception,
            "Error {CorrelationId}: {Message}",
            correlationId,
            context.Exception.Message);

        context.Result = new ObjectResult(problemDetails)
        {
            StatusCode = problemDetails.Status
        };
        context.ExceptionHandled = true;
    }
}
```

---

## Best Practices

### Do

```csharp
// ✅ Use specific exception types
throw new EntityNotFoundException(nameof(Product), productId);

// ✅ Include contextual information
throw new BusinessRuleException(
    $"Cannot delete order {orderId} because it has already been shipped.");

// ✅ Use Problem Details format (RFC 7807)
return new ProblemDetails { Type = "...", Title = "...", Status = 400 };

// ✅ Log with correlation ID
logger.LogError(ex, "Error {CorrelationId}: {Message}", correlationId, ex.Message);

// ✅ Hide internal details in production
if (environment.IsDevelopment())
    problemDetails.Extensions["stackTrace"] = ex.StackTrace;
```

### Don't

```csharp
// ❌ Generic exceptions
throw new Exception("Something went wrong");

// ❌ Exposing internal details
return new ProblemDetails { Detail = ex.StackTrace };

// ❌ Catching and swallowing exceptions
try { ... }
catch { }  // Silent failure

// ❌ Returning error details in response body for 500 errors (production)
return new { error = ex.ToString() };  // Security risk

// ❌ Inconsistent error response formats
return BadRequest("Error");  // String
return BadRequest(new { message = "Error" });  // Anonymous object
```
