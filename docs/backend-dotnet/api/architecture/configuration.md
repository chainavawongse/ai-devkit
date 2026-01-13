# Configuration

Settings, secrets, and environment management patterns.

## Configuration Sources

ASP.NET Core loads configuration in order (later sources override earlier):

1. `appsettings.json`
2. `appsettings.{Environment}.json`
3. User secrets (Development only)
4. Environment variables
5. Command-line arguments

```csharp
// Program.cs - Default configuration is automatic
var builder = WebApplication.CreateBuilder(args);

// Access configuration
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
```

---

## Settings Structure

### appsettings.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning"
    }
  },
  "AllowedHosts": "*",

  "Database": {
    "CommandTimeout": 30,
    "EnableSensitiveDataLogging": false
  },

  "Authentication": {
    "Jwt": {
      "Issuer": "https://myapp.com",
      "Audience": "myapp-api",
      "ExpirationMinutes": 60
    }
  },

  "ExternalServices": {
    "EmailService": {
      "BaseUrl": "https://email-api.example.com",
      "TimeoutSeconds": 30
    }
  },

  "FeatureFlags": {
    "EnableNewDashboard": false,
    "EnableBetaFeatures": false
  }
}
```

### appsettings.Development.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft.EntityFrameworkCore.Database.Command": "Information"
    }
  },

  "Database": {
    "EnableSensitiveDataLogging": true
  },

  "FeatureFlags": {
    "EnableBetaFeatures": true
  }
}
```

---

## Strongly-Typed Settings

### Define Settings Classes

```csharp
// Settings/DatabaseSettings.cs
public class DatabaseSettings
{
    public const string SectionName = "Database";

    public required string ConnectionString { get; init; }
    public int CommandTimeout { get; init; } = 30;
    public bool EnableSensitiveDataLogging { get; init; } = false;
    public int MaxRetryCount { get; init; } = 3;
}

// Settings/JwtSettings.cs
public class JwtSettings
{
    public const string SectionName = "Authentication:Jwt";

    public required string Issuer { get; init; }
    public required string Audience { get; init; }
    public required string Secret { get; init; }
    public int ExpirationMinutes { get; init; } = 60;
}

// Settings/ExternalServiceSettings.cs
public class ExternalServiceSettings
{
    public required string BaseUrl { get; init; }
    public int TimeoutSeconds { get; init; } = 30;
    public int RetryCount { get; init; } = 3;
}
```

### Register Settings

```csharp
// Program.cs or ServiceCollectionExtensions.cs
public static IServiceCollection AddConfigurationSettings(
    this IServiceCollection services,
    IConfiguration configuration)
{
    // Basic binding
    services.Configure<DatabaseSettings>(
        configuration.GetSection(DatabaseSettings.SectionName));

    // With validation
    services.AddOptions<JwtSettings>()
        .Bind(configuration.GetSection(JwtSettings.SectionName))
        .ValidateDataAnnotations()
        .ValidateOnStart();  // Fail fast on startup if invalid

    // Named options for multiple instances
    services.Configure<ExternalServiceSettings>(
        "EmailService",
        configuration.GetSection("ExternalServices:EmailService"));

    services.Configure<ExternalServiceSettings>(
        "PaymentService",
        configuration.GetSection("ExternalServices:PaymentService"));

    return services;
}
```

### Inject Settings

```csharp
// IOptions<T> - Singleton, read once at startup
public class ServiceA(IOptions<DatabaseSettings> options)
{
    private readonly DatabaseSettings _settings = options.Value;
}

// IOptionsSnapshot<T> - Scoped, reloads on each request
public class ServiceB(IOptionsSnapshot<JwtSettings> options)
{
    private readonly JwtSettings _settings = options.Value;
}

// IOptionsMonitor<T> - Singleton with change notifications
public class ServiceC(IOptionsMonitor<FeatureFlags> options)
{
    public bool IsFeatureEnabled()
    {
        return options.CurrentValue.EnableNewDashboard;
    }
}

// Named options
public class ServiceD(IOptionsSnapshot<ExternalServiceSettings> options)
{
    public void SendEmail()
    {
        var emailSettings = options.Get("EmailService");
    }
}
```

---

## Secrets Management

### User Secrets (Development)

```bash
# Initialize user secrets
dotnet user-secrets init --project src/MyApp.Api

# Set secrets
dotnet user-secrets set "Database:ConnectionString" "Host=localhost;Database=myapp;..." --project src/MyApp.Api
dotnet user-secrets set "Authentication:Jwt:Secret" "your-super-secret-key" --project src/MyApp.Api

# List secrets
dotnet user-secrets list --project src/MyApp.Api

# Remove secret
dotnet user-secrets remove "SomeKey" --project src/MyApp.Api
```

Secrets are stored in:

- Windows: `%APPDATA%\Microsoft\UserSecrets\<user_secrets_id>\secrets.json`
- macOS/Linux: `~/.microsoft/usersecrets/<user_secrets_id>/secrets.json`

### Environment Variables (Production)

```bash
# Connection strings
export ConnectionStrings__DefaultConnection="Host=prod-db;..."

# Nested settings use double underscore
export Authentication__Jwt__Secret="production-secret"
export ExternalServices__EmailService__BaseUrl="https://prod-email.example.com"
```

### Azure Key Vault (Production)

```csharp
// Program.cs
builder.Configuration.AddAzureKeyVault(
    new Uri($"https://{vaultName}.vault.azure.net/"),
    new DefaultAzureCredential());
```

---

## Connection Strings

### Configuration

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Database=myapp;Username=user;Password=pass",
    "ReadOnlyConnection": "Host=readonly-replica;Database=myapp;..."
  }
}
```

### Access

```csharp
// Direct access
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

// In DbContext registration
services.AddDbContext<AppDbContext>(options =>
{
    options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
});
```

---

## Environment-Based Configuration

### Check Environment

```csharp
var builder = WebApplication.CreateBuilder(args);

if (builder.Environment.IsDevelopment())
{
    // Development-only configuration
    builder.Services.AddSwaggerGen();
}

if (builder.Environment.IsProduction())
{
    // Production-only configuration
    builder.Services.AddApplicationInsightsTelemetry();
}
```

### Custom Environments

```bash
# Set environment
export ASPNETCORE_ENVIRONMENT=Staging

# Or via launch settings
# Properties/launchSettings.json
{
  "profiles": {
    "Staging": {
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Staging"
      }
    }
  }
}
```

---

## Validation

### Data Annotations

```csharp
public class JwtSettings
{
    [Required]
    [Url]
    public required string Issuer { get; init; }

    [Required]
    public required string Audience { get; init; }

    [Required]
    [MinLength(32)]
    public required string Secret { get; init; }

    [Range(1, 1440)]
    public int ExpirationMinutes { get; init; } = 60;
}
```

### Custom Validation

```csharp
services.AddOptions<JwtSettings>()
    .Bind(configuration.GetSection(JwtSettings.SectionName))
    .Validate(settings =>
    {
        if (settings.ExpirationMinutes < 1)
            return false;
        if (string.IsNullOrEmpty(settings.Secret) || settings.Secret.Length < 32)
            return false;
        return true;
    }, "JWT settings are invalid")
    .ValidateOnStart();
```

### FluentValidation for Settings

```csharp
public class JwtSettingsValidator : AbstractValidator<JwtSettings>
{
    public JwtSettingsValidator()
    {
        RuleFor(x => x.Issuer).NotEmpty().Must(BeValidUrl);
        RuleFor(x => x.Audience).NotEmpty();
        RuleFor(x => x.Secret).NotEmpty().MinimumLength(32);
        RuleFor(x => x.ExpirationMinutes).InclusiveBetween(1, 1440);
    }

    private bool BeValidUrl(string url) => Uri.TryCreate(url, UriKind.Absolute, out _);
}
```

---

## Feature Flags

### Basic Feature Flags

```csharp
// Settings class
public class FeatureFlags
{
    public bool EnableNewDashboard { get; init; }
    public bool EnableBetaFeatures { get; init; }
    public bool EnableExperimentalApi { get; init; }
}

// Registration
services.Configure<FeatureFlags>(configuration.GetSection("FeatureFlags"));

// Usage
public class DashboardController(IOptions<FeatureFlags> features) : ControllerBase
{
    [HttpGet]
    public IActionResult GetDashboard()
    {
        if (!features.Value.EnableNewDashboard)
        {
            return RedirectToAction("LegacyDashboard");
        }
        // New dashboard logic
    }
}
```

### Microsoft Feature Management

```bash
dotnet add package Microsoft.FeatureManagement.AspNetCore
```

```csharp
// Program.cs
builder.Services.AddFeatureManagement();

// Controller
public class ProductsController(IFeatureManager featureManager) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get()
    {
        if (await featureManager.IsEnabledAsync("NewProductList"))
        {
            // New implementation
        }
        // Legacy implementation
    }
}

// Attribute-based
[FeatureGate("BetaFeatures")]
[HttpGet("beta")]
public IActionResult GetBetaFeature() => Ok();
```

---

## Best Practices

### Do

```csharp
// ✅ Use strongly-typed settings
services.Configure<DatabaseSettings>(configuration.GetSection("Database"));

// ✅ Validate settings on startup
.ValidateDataAnnotations()
.ValidateOnStart();

// ✅ Use user secrets for local development
dotnet user-secrets set "Key" "Value"

// ✅ Use environment variables or Key Vault for production secrets

// ✅ Provide sensible defaults
public int CommandTimeout { get; init; } = 30;
```

### Don't

```csharp
// ❌ Hardcode secrets
var secret = "my-super-secret-key";

// ❌ Commit secrets to source control
// appsettings.json: "Secret": "production-secret"

// ❌ Use magic strings repeatedly
configuration["Database:ConnectionString"]  // Use GetConnectionString or typed settings

// ❌ Access IConfiguration directly in services
public class BadService(IConfiguration config)  // Use IOptions<T> instead
```

---

## Configuration Hierarchy Example

```
Base settings (appsettings.json)
    ↓
Environment settings (appsettings.Production.json)
    ↓
User secrets (Development only)
    ↓
Environment variables
    ↓
Azure Key Vault / AWS Secrets Manager
    ↓
Command-line arguments
```

Later sources override earlier sources. This allows:

- Default values in `appsettings.json`
- Environment-specific overrides
- Secrets outside of source control
- Runtime overrides for containers/orchestration
