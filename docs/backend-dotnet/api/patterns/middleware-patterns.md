# Middleware Patterns

Custom middleware for cross-cutting concerns in the request pipeline.

## Middleware Basics

```csharp
// Middleware class pattern
public class CustomMiddleware(
    RequestDelegate next,
    ILogger<CustomMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        // Before next middleware
        logger.LogInformation("Request starting: {Path}", context.Request.Path);

        await next(context);

        // After next middleware
        logger.LogInformation("Request completed: {StatusCode}", context.Response.StatusCode);
    }
}

// Registration
app.UseMiddleware<CustomMiddleware>();
```

---

## Correlation ID Middleware

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

        // Add to logging scope
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

// Extension method
public static class CorrelationIdMiddlewareExtensions
{
    public static IApplicationBuilder UseCorrelationId(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<CorrelationIdMiddleware>();
    }
}
```

---

## Request Logging Middleware

```csharp
public class RequestLoggingMiddleware(
    RequestDelegate next,
    ILogger<RequestLoggingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        var stopwatch = Stopwatch.StartNew();

        try
        {
            await next(context);
        }
        finally
        {
            stopwatch.Stop();

            logger.LogInformation(
                "HTTP {Method} {Path} responded {StatusCode} in {ElapsedMs}ms",
                context.Request.Method,
                context.Request.Path,
                context.Response.StatusCode,
                stopwatch.ElapsedMilliseconds);
        }
    }
}
```

### With Request/Response Body Logging

```csharp
public class DetailedRequestLoggingMiddleware(
    RequestDelegate next,
    ILogger<DetailedRequestLoggingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        // Log request
        context.Request.EnableBuffering();
        var requestBody = await ReadRequestBodyAsync(context.Request);

        logger.LogDebug(
            "Request {Method} {Path}: {Body}",
            context.Request.Method,
            context.Request.Path,
            requestBody);

        // Capture response
        var originalBodyStream = context.Response.Body;
        using var responseBody = new MemoryStream();
        context.Response.Body = responseBody;

        await next(context);

        // Log response
        var responseContent = await ReadResponseBodyAsync(context.Response);
        logger.LogDebug(
            "Response {StatusCode}: {Body}",
            context.Response.StatusCode,
            responseContent);

        // Copy response back
        await responseBody.CopyToAsync(originalBodyStream);
    }

    private static async Task<string> ReadRequestBodyAsync(HttpRequest request)
    {
        request.Body.Position = 0;
        using var reader = new StreamReader(request.Body, leaveOpen: true);
        var body = await reader.ReadToEndAsync();
        request.Body.Position = 0;
        return body;
    }

    private static async Task<string> ReadResponseBodyAsync(HttpResponse response)
    {
        response.Body.Seek(0, SeekOrigin.Begin);
        var text = await new StreamReader(response.Body).ReadToEndAsync();
        response.Body.Seek(0, SeekOrigin.Begin);
        return text;
    }
}
```

---

## Audit Context Middleware

Set audit information for the request:

```csharp
public class AuditContextMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context, IAuditContext auditContext)
    {
        if (context.User.Identity?.IsAuthenticated == true)
        {
            var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
            var userName = context.User.FindFirstValue(ClaimTypes.Name);
            var email = context.User.FindFirstValue(ClaimTypes.Email);

            auditContext.SetUser(
                userId is not null ? Guid.Parse(userId) : null,
                userName,
                email);
        }

        auditContext.SetCorrelationId(
            context.Request.Headers["X-Correlation-Id"].FirstOrDefault()
                ?? Guid.NewGuid().ToString());

        await next(context);
    }
}

// Audit context service
public interface IAuditContext
{
    Guid? UserId { get; }
    string? UserName { get; }
    string? Email { get; }
    string CorrelationId { get; }
    void SetUser(Guid? userId, string? userName, string? email);
    void SetCorrelationId(string correlationId);
}

public class AuditContext : IAuditContext
{
    public Guid? UserId { get; private set; }
    public string? UserName { get; private set; }
    public string? Email { get; private set; }
    public string CorrelationId { get; private set; } = string.Empty;

    public void SetUser(Guid? userId, string? userName, string? email)
    {
        UserId = userId;
        UserName = userName;
        Email = email;
    }

    public void SetCorrelationId(string correlationId)
    {
        CorrelationId = correlationId;
    }
}

// Registration
services.AddScoped<IAuditContext, AuditContext>();
```

---

## Rate Limiting Middleware

```csharp
public class RateLimitingMiddleware(
    RequestDelegate next,
    IMemoryCache cache,
    ILogger<RateLimitingMiddleware> logger)
{
    private const int MaxRequests = 100;
    private static readonly TimeSpan Window = TimeSpan.FromMinutes(1);

    public async Task InvokeAsync(HttpContext context)
    {
        var clientId = GetClientIdentifier(context);
        var cacheKey = $"rate_limit_{clientId}";

        var requestCount = cache.GetOrCreate(cacheKey, entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = Window;
            return 0;
        });

        if (requestCount >= MaxRequests)
        {
            logger.LogWarning("Rate limit exceeded for client {ClientId}", clientId);

            context.Response.StatusCode = StatusCodes.Status429TooManyRequests;
            context.Response.Headers.RetryAfter = "60";
            await context.Response.WriteAsJsonAsync(new ProblemDetails
            {
                Title = "Too Many Requests",
                Status = 429,
                Detail = "Rate limit exceeded. Please try again later."
            });
            return;
        }

        cache.Set(cacheKey, requestCount + 1, Window);

        await next(context);
    }

    private static string GetClientIdentifier(HttpContext context)
    {
        // Use authenticated user ID if available
        var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!string.IsNullOrEmpty(userId))
            return userId;

        // Fall back to IP address
        return context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
    }
}
```

---

## Tenant Resolution Middleware

For multi-tenant applications:

```csharp
public class TenantResolutionMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context, ITenantContext tenantContext)
    {
        var tenantId = ResolveTenantId(context);

        if (tenantId is null)
        {
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            await context.Response.WriteAsJsonAsync(new ProblemDetails
            {
                Title = "Tenant Not Found",
                Status = 400,
                Detail = "Unable to resolve tenant from request."
            });
            return;
        }

        tenantContext.SetTenant(tenantId.Value);

        await next(context);
    }

    private static Guid? ResolveTenantId(HttpContext context)
    {
        // Option 1: From subdomain
        var host = context.Request.Host.Host;
        // tenant1.example.com -> tenant1

        // Option 2: From header
        if (context.Request.Headers.TryGetValue("X-Tenant-Id", out var tenantHeader)
            && Guid.TryParse(tenantHeader, out var tenantId))
        {
            return tenantId;
        }

        // Option 3: From claims
        var tenantClaim = context.User.FindFirstValue("TenantId");
        if (Guid.TryParse(tenantClaim, out var claimTenantId))
        {
            return claimTenantId;
        }

        return null;
    }
}
```

---

## Response Compression Configuration

```csharp
// Program.cs
builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;
    options.Providers.Add<BrotliCompressionProvider>();
    options.Providers.Add<GzipCompressionProvider>();
    options.MimeTypes = ResponseCompressionDefaults.MimeTypes.Concat(
        ["application/json", "application/problem+json"]);
});

builder.Services.Configure<BrotliCompressionProviderOptions>(options =>
{
    options.Level = CompressionLevel.Fastest;
});

// Must be before static files and endpoints
app.UseResponseCompression();
```

---

## Security Headers Middleware

```csharp
public class SecurityHeadersMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context)
    {
        // Prevent clickjacking
        context.Response.Headers.XFrameOptions = "DENY";

        // Prevent MIME sniffing
        context.Response.Headers.XContentTypeOptions = "nosniff";

        // XSS protection
        context.Response.Headers["X-XSS-Protection"] = "1; mode=block";

        // Referrer policy
        context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";

        // Content Security Policy
        context.Response.Headers.ContentSecurityPolicy =
            "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'";

        // HSTS (for HTTPS)
        if (context.Request.IsHttps)
        {
            context.Response.Headers.StrictTransportSecurity =
                "max-age=31536000; includeSubDomains";
        }

        await next(context);
    }
}
```

---

## Middleware Order

Order matters! Configure in Program.cs:

```csharp
var app = builder.Build();

// 1. Exception handling (first to catch all)
app.UseExceptionHandler("/error");

// 2. HSTS (before any response)
if (app.Environment.IsProduction())
{
    app.UseHsts();
}

// 3. HTTPS redirection
app.UseHttpsRedirection();

// 4. Response compression (before static files)
app.UseResponseCompression();

// 5. Static files
app.UseStaticFiles();

// 6. Routing (determines endpoint)
app.UseRouting();

// 7. CORS (before auth, after routing)
app.UseCors("AllowSpecificOrigins");

// 8. Custom middleware
app.UseCorrelationId();
app.UseSecurityHeaders();
app.UseRequestLogging();

// 9. Authentication (who are you?)
app.UseAuthentication();

// 10. Tenant resolution (after auth, needs user claims)
app.UseMiddleware<TenantResolutionMiddleware>();

// 11. Audit context
app.UseMiddleware<AuditContextMiddleware>();

// 12. Authorization (what can you do?)
app.UseAuthorization();

// 13. Rate limiting
app.UseMiddleware<RateLimitingMiddleware>();

// 14. Endpoints (last)
app.MapControllers();
```

---

## Conditional Middleware

```csharp
// Apply only in specific environments
if (app.Environment.IsDevelopment())
{
    app.UseMiddleware<DetailedRequestLoggingMiddleware>();
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Apply based on path
app.UseWhen(
    context => context.Request.Path.StartsWithSegments("/api"),
    appBuilder => appBuilder.UseMiddleware<ApiRateLimitingMiddleware>());

// Apply based on condition
app.MapWhen(
    context => context.Request.Headers.ContainsKey("X-Custom-Header"),
    appBuilder => appBuilder.UseMiddleware<CustomHeaderMiddleware>());
```

---

## Testing Middleware

```csharp
public class CorrelationIdMiddlewareTests
{
    [Fact]
    public async Task InvokeAsync_NoCorrelationIdHeader_GeneratesNew()
    {
        // Arrange
        var context = new DefaultHttpContext();
        var middleware = new CorrelationIdMiddleware(_ => Task.CompletedTask);

        // Act
        await middleware.InvokeAsync(context);

        // Assert
        context.Response.Headers.Should().ContainKey("X-Correlation-Id");
        context.Response.Headers["X-Correlation-Id"].ToString()
            .Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task InvokeAsync_HasCorrelationIdHeader_UsesSameId()
    {
        // Arrange
        var existingId = "existing-correlation-id";
        var context = new DefaultHttpContext();
        context.Request.Headers["X-Correlation-Id"] = existingId;

        var middleware = new CorrelationIdMiddleware(_ => Task.CompletedTask);

        // Act
        await middleware.InvokeAsync(context);

        // Assert
        context.Response.Headers["X-Correlation-Id"].ToString()
            .Should().Be(existingId);
    }
}
```

---

## Best Practices

### Do

```csharp
// ✅ Use extension methods for cleaner registration
app.UseCorrelationId();

// ✅ Keep middleware focused on single responsibility
public class CorrelationIdMiddleware { }  // Only handles correlation ID

// ✅ Use dependency injection via InvokeAsync
public async Task InvokeAsync(HttpContext context, IMyService service)

// ✅ Handle exceptions gracefully
try { await next(context); }
catch (Exception ex) { /* log and handle */ }

// ✅ Set response headers before body is written
context.Response.OnStarting(() => { /* set headers */ });
```

### Don't

```csharp
// ❌ Modify response after next() completes
await next(context);
context.Response.Headers.Add("X-Header", "value");  // May throw

// ❌ Block the pipeline unnecessarily
Thread.Sleep(1000);  // Use async

// ❌ Create middleware with constructor dependencies that need scoped lifetime
public class BadMiddleware(IScoped service)  // Scoped in singleton!
{
    // Use InvokeAsync parameter injection instead
}

// ❌ Put too much logic in middleware
// Complex business logic belongs in handlers/services
```
