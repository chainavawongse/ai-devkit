# Authentication

JWT authentication with OAuth social provider support (Google, GitHub, Apple, Microsoft).

## Overview

This guide covers a flexible authentication strategy:

- **JWT tokens** for API authentication
- **OAuth providers** for social login (Google, GitHub, Apple, Microsoft)
- **Unified user identity** regardless of authentication method

---

## Setup

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add package Microsoft.AspNetCore.Authentication.Google
dotnet add package Microsoft.AspNetCore.Authentication.MicrosoftAccount
dotnet add package AspNet.Security.OAuth.GitHub
dotnet add package AspNet.Security.OAuth.Apple
```

---

## JWT Configuration

### Settings

```json
// appsettings.json
{
  "Authentication": {
    "Jwt": {
      "Issuer": "https://myapp.com",
      "Audience": "myapp-api",
      "ExpirationMinutes": 60,
      "RefreshTokenExpirationDays": 7
    }
  }
}
```

```csharp
// Settings class
public class JwtSettings
{
    public const string SectionName = "Authentication:Jwt";

    public required string Issuer { get; init; }
    public required string Audience { get; init; }
    public required string Secret { get; init; }  // From user secrets/env
    public int ExpirationMinutes { get; init; } = 60;
    public int RefreshTokenExpirationDays { get; init; } = 7;
}
```

### Registration

```csharp
// Program.cs
var jwtSettings = builder.Configuration
    .GetSection(JwtSettings.SectionName)
    .Get<JwtSettings>()!;

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidIssuer = jwtSettings.Issuer,

        ValidateAudience = true,
        ValidAudience = jwtSettings.Audience,

        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(jwtSettings.Secret)),

        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero
    };

    options.Events = new JwtBearerEvents
    {
        OnAuthenticationFailed = context =>
        {
            if (context.Exception is SecurityTokenExpiredException)
            {
                context.Response.Headers.Append("Token-Expired", "true");
            }
            return Task.CompletedTask;
        }
    };
});
```

---

## JWT Token Service

```csharp
// Contracts/Interfaces/ITokenService.cs
public interface ITokenService
{
    string GenerateAccessToken(UserEntity user, IEnumerable<string> roles);
    RefreshToken GenerateRefreshToken();
    ClaimsPrincipal? ValidateExpiredToken(string token);
}

// Services/TokenService.cs
public class TokenService(IOptions<JwtSettings> jwtSettings) : ITokenService
{
    private readonly JwtSettings _settings = jwtSettings.Value;

    public string GenerateAccessToken(UserEntity user, IEnumerable<string> roles)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Name, user.DisplayName ?? user.Email),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        claims.AddRange(roles.Select(role => new Claim(ClaimTypes.Role, role)));

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_settings.Secret));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _settings.Issuer,
            audience: _settings.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(_settings.ExpirationMinutes),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public RefreshToken GenerateRefreshToken()
    {
        return new RefreshToken
        {
            Token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64)),
            ExpiresAt = DateTime.UtcNow.AddDays(_settings.RefreshTokenExpirationDays),
            CreatedAt = DateTime.UtcNow
        };
    }

    public ClaimsPrincipal? ValidateExpiredToken(string token)
    {
        var tokenHandler = new JwtSecurityTokenHandler();
        var key = Encoding.UTF8.GetBytes(_settings.Secret);

        try
        {
            var principal = tokenHandler.ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = _settings.Issuer,
                ValidateAudience = true,
                ValidAudience = _settings.Audience,
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(key),
                ValidateLifetime = false  // Allow expired tokens for refresh
            }, out var validatedToken);

            return principal;
        }
        catch
        {
            return null;
        }
    }
}
```

---

## OAuth Social Providers

### Configuration

```csharp
// Program.cs
builder.Services.AddAuthentication()
    .AddJwtBearer(/* ... */)

    .AddGoogle(options =>
    {
        options.ClientId = builder.Configuration["Authentication:Google:ClientId"]!;
        options.ClientSecret = builder.Configuration["Authentication:Google:ClientSecret"]!;
        options.Scope.Add("email");
        options.Scope.Add("profile");
    })

    .AddGitHub(options =>
    {
        options.ClientId = builder.Configuration["Authentication:GitHub:ClientId"]!;
        options.ClientSecret = builder.Configuration["Authentication:GitHub:ClientSecret"]!;
        options.Scope.Add("user:email");
    })

    .AddMicrosoftAccount(options =>
    {
        options.ClientId = builder.Configuration["Authentication:Microsoft:ClientId"]!;
        options.ClientSecret = builder.Configuration["Authentication:Microsoft:ClientSecret"]!;
    })

    .AddApple(options =>
    {
        options.ClientId = builder.Configuration["Authentication:Apple:ClientId"]!;
        options.KeyId = builder.Configuration["Authentication:Apple:KeyId"]!;
        options.TeamId = builder.Configuration["Authentication:Apple:TeamId"]!;
        options.PrivateKey = (keyId, teamId) =>
            File.ReadAllText(builder.Configuration["Authentication:Apple:PrivateKeyPath"]!)
                .AsMemory();
    });
```

### Settings Structure

```json
{
  "Authentication": {
    "Jwt": { /* ... */ },
    "Google": {
      "ClientId": "your-google-client-id",
      "ClientSecret": "your-google-client-secret"
    },
    "GitHub": {
      "ClientId": "your-github-client-id",
      "ClientSecret": "your-github-client-secret"
    },
    "Microsoft": {
      "ClientId": "your-microsoft-client-id",
      "ClientSecret": "your-microsoft-client-secret"
    },
    "Apple": {
      "ClientId": "your-apple-service-id",
      "KeyId": "your-key-id",
      "TeamId": "your-team-id",
      "PrivateKeyPath": "path/to/AuthKey.p8"
    }
  }
}
```

---

## Authentication Controller

```csharp
[ApiController]
[Route("api/[controller]")]
public class AuthController(
    IMediator mediator,
    ITokenService tokenService
) : ControllerBase
{
    // Email/Password login
    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(
        LoginRequest request,
        CancellationToken cancellationToken)
    {
        var command = new LoginCommand(request.Email, request.Password);
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    // Register new user
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(
        RegisterRequest request,
        CancellationToken cancellationToken)
    {
        var command = new RegisterCommand(request);
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    // Refresh token
    [HttpPost("refresh")]
    public async Task<ActionResult<AuthResponse>> Refresh(
        RefreshTokenRequest request,
        CancellationToken cancellationToken)
    {
        var command = new RefreshTokenCommand(request.AccessToken, request.RefreshToken);
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    // OAuth callback (handles all providers)
    [HttpGet("external/{provider}")]
    public IActionResult ExternalLogin(string provider, string returnUrl = "/")
    {
        var properties = new AuthenticationProperties
        {
            RedirectUri = Url.Action(nameof(ExternalLoginCallback), new { returnUrl }),
            Items = { { "provider", provider } }
        };

        return Challenge(properties, provider);
    }

    [HttpGet("external-callback")]
    public async Task<ActionResult<AuthResponse>> ExternalLoginCallback(
        string returnUrl,
        CancellationToken cancellationToken)
    {
        var result = await HttpContext.AuthenticateAsync();

        if (!result.Succeeded)
        {
            return Unauthorized(new ProblemDetails
            {
                Title = "External authentication failed",
                Status = 401
            });
        }

        var command = new ExternalLoginCommand(
            Provider: result.Properties?.Items["provider"] ?? "unknown",
            ProviderKey: result.Principal!.FindFirstValue(ClaimTypes.NameIdentifier)!,
            Email: result.Principal.FindFirstValue(ClaimTypes.Email)!,
            Name: result.Principal.FindFirstValue(ClaimTypes.Name));

        var authResult = await mediator.Send(command, cancellationToken);

        // Redirect to frontend with token (or return JSON for SPA)
        return Ok(authResult);
    }

    // Logout
    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(CancellationToken cancellationToken)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var command = new LogoutCommand(userId);
        await mediator.Send(command, cancellationToken);
        return NoContent();
    }
}
```

---

## User Entity with External Logins

```csharp
// Data/Entities/UserEntity.cs
public class UserEntity : BaseEntity<Guid>
{
    public required string Email { get; set; }
    public string? PasswordHash { get; set; }  // Null for external-only users
    public string? DisplayName { get; set; }
    public string? AvatarUrl { get; set; }
    public bool EmailConfirmed { get; set; }
    public DateTime? LastLoginAt { get; set; }

    // Navigation
    public ICollection<UserExternalLoginEntity> ExternalLogins { get; set; } = [];
    public ICollection<RefreshTokenEntity> RefreshTokens { get; set; } = [];
    public ICollection<UserRoleEntity> UserRoles { get; set; } = [];
}

// Data/Entities/UserExternalLoginEntity.cs
public class UserExternalLoginEntity
{
    public long Id { get; set; }
    public Guid UserId { get; set; }
    public required string Provider { get; set; }  // "Google", "GitHub", etc.
    public required string ProviderKey { get; set; }  // External user ID
    public string? ProviderDisplayName { get; set; }
    public DateTime CreatedAt { get; set; }

    public UserEntity User { get; set; } = null!;
}

// Data/Entities/RefreshTokenEntity.cs
public class RefreshTokenEntity
{
    public long Id { get; set; }
    public Guid UserId { get; set; }
    public required string Token { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? RevokedAt { get; set; }
    public string? ReplacedByToken { get; set; }

    public bool IsExpired => DateTime.UtcNow >= ExpiresAt;
    public bool IsRevoked => RevokedAt.HasValue;
    public bool IsActive => !IsRevoked && !IsExpired;

    public UserEntity User { get; set; } = null!;
}
```

---

## External Login Handler

```csharp
// Services/Handlers/Commands/ExternalLoginCommandHandler.cs
public class ExternalLoginCommandHandler(
    IUserRepository userRepository,
    ITokenService tokenService,
    IMapper mapper
) : IRequestHandler<ExternalLoginCommand, AuthResponse>
{
    public async Task<AuthResponse> Handle(
        ExternalLoginCommand request,
        CancellationToken cancellationToken)
    {
        // Check if external login exists
        var existingLogin = await userRepository.GetExternalLoginAsync(
            request.Provider,
            request.ProviderKey,
            cancellationToken);

        UserEntity user;

        if (existingLogin is not null)
        {
            // Existing external login - get user
            user = existingLogin.User;
        }
        else
        {
            // Check if user exists with same email
            user = await userRepository.GetByEmailAsync(request.Email, cancellationToken)
                ?? await CreateUserAsync(request, cancellationToken);

            // Link external login to user
            await userRepository.AddExternalLoginAsync(new UserExternalLoginEntity
            {
                UserId = user.Id,
                Provider = request.Provider,
                ProviderKey = request.ProviderKey,
                ProviderDisplayName = request.Name,
                CreatedAt = DateTime.UtcNow
            }, cancellationToken);
        }

        // Update last login
        user.LastLoginAt = DateTime.UtcNow;
        await userRepository.UpdateAsync(user, cancellationToken);

        // Generate tokens
        var roles = await userRepository.GetRolesAsync(user.Id, cancellationToken);
        var accessToken = tokenService.GenerateAccessToken(user, roles);
        var refreshToken = tokenService.GenerateRefreshToken();

        await userRepository.AddRefreshTokenAsync(new RefreshTokenEntity
        {
            UserId = user.Id,
            Token = refreshToken.Token,
            ExpiresAt = refreshToken.ExpiresAt,
            CreatedAt = refreshToken.CreatedAt
        }, cancellationToken);

        return new AuthResponse
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken.Token,
            ExpiresAt = DateTime.UtcNow.AddMinutes(60),
            User = mapper.Map<UserDto>(user)
        };
    }

    private async Task<UserEntity> CreateUserAsync(
        ExternalLoginCommand request,
        CancellationToken cancellationToken)
    {
        var user = new UserEntity
        {
            Id = Guid.NewGuid(),
            Email = request.Email,
            DisplayName = request.Name,
            EmailConfirmed = true,  // External provider already verified
            CreatedAt = DateTime.UtcNow
        };

        await userRepository.AddAsync(user, cancellationToken);
        return user;
    }
}
```

---

## DTOs and Commands

```csharp
// Contracts
public record LoginRequest(string Email, string Password);
public record RegisterRequest(string Email, string Password, string? DisplayName);
public record RefreshTokenRequest(string AccessToken, string RefreshToken);

public record AuthResponse
{
    public required string AccessToken { get; init; }
    public required string RefreshToken { get; init; }
    public required DateTime ExpiresAt { get; init; }
    public required UserDto User { get; init; }
}

public record LoginCommand(string Email, string Password) : IRequest<AuthResponse>;
public record RegisterCommand(RegisterRequest Request) : IRequest<AuthResponse>;
public record RefreshTokenCommand(string AccessToken, string RefreshToken) : IRequest<AuthResponse>;
public record ExternalLoginCommand(
    string Provider,
    string ProviderKey,
    string Email,
    string? Name
) : IRequest<AuthResponse>;
public record LogoutCommand(Guid UserId) : IRequest;
```

---

## Protecting Endpoints

```csharp
// Require authentication
[Authorize]
[HttpGet("profile")]
public async Task<ActionResult<UserDto>> GetProfile() { }

// Require specific role
[Authorize(Roles = "Admin")]
[HttpDelete("{id}")]
public async Task<IActionResult> DeleteUser(Guid id) { }

// Require specific policy (see authorization.md)
[Authorize(Policy = "CanManageProducts")]
[HttpPut("{id}")]
public async Task<ActionResult<ProductDto>> UpdateProduct(long id) { }

// Allow anonymous
[AllowAnonymous]
[HttpGet("public-data")]
public ActionResult<PublicDataDto> GetPublicData() { }
```

---

## Best Practices

### Do

```csharp
// ✅ Store secrets securely
var secret = builder.Configuration["Authentication:Jwt:Secret"];  // From env/vault

// ✅ Use short-lived access tokens
ExpirationMinutes = 15  // 15-60 minutes

// ✅ Rotate refresh tokens on use
await RevokeRefreshToken(oldToken);
var newToken = GenerateRefreshToken();

// ✅ Validate all token parameters
ValidateIssuer = true,
ValidateAudience = true,
ValidateLifetime = true

// ✅ Hash passwords properly
var hash = BCrypt.HashPassword(password, BCrypt.GenerateSalt(12));
```

### Don't

```csharp
// ❌ Store secrets in code or appsettings.json
var secret = "hardcoded-secret-key";

// ❌ Long-lived access tokens
ExpirationMinutes = 43200  // 30 days - too long!

// ❌ Skip validation
ValidateLifetime = false

// ❌ Use weak hashing
var hash = MD5.ComputeHash(password);  // Use BCrypt or Argon2

// ❌ Return sensitive data in tokens
claims.Add(new Claim("password", user.Password));  // Never!
```
