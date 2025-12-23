# Authorization

Policy-based authorization with custom requirements and handlers.

## Overview

Authorization determines what authenticated users can do:
- **Role-based**: User has role "Admin", "Manager", etc.
- **Policy-based**: User meets custom requirements
- **Resource-based**: User has permission for specific resource

---

## Setup

```csharp
// Program.cs
builder.Services.AddAuthorization(options =>
{
    // Simple role-based policies
    options.AddPolicy("RequireAdmin", policy =>
        policy.RequireRole("Admin"));

    options.AddPolicy("RequireManager", policy =>
        policy.RequireRole("Admin", "Manager"));

    // Custom policies
    options.AddPolicy("CanManageProducts", policy =>
        policy.Requirements.Add(new PermissionRequirement("products:write")));

    options.AddPolicy("CanViewReports", policy =>
        policy.Requirements.Add(new PermissionRequirement("reports:read")));

    options.AddPolicy("MustBeResourceOwner", policy =>
        policy.Requirements.Add(new ResourceOwnerRequirement()));
});

// Register handlers
builder.Services.AddScoped<IAuthorizationHandler, PermissionHandler>();
builder.Services.AddScoped<IAuthorizationHandler, ResourceOwnerHandler>();
```

---

## Role-Based Authorization

### Define Roles

```csharp
public static class Roles
{
    public const string Admin = "Admin";
    public const string Manager = "Manager";
    public const string User = "User";
    public const string ReadOnly = "ReadOnly";
}
```

### Include Roles in JWT

```csharp
// In TokenService
public string GenerateAccessToken(UserEntity user, IEnumerable<string> roles)
{
    var claims = new List<Claim>
    {
        new(ClaimTypes.NameIdentifier, user.Id.ToString()),
        new(ClaimTypes.Email, user.Email),
    };

    // Add role claims
    claims.AddRange(roles.Select(role => new Claim(ClaimTypes.Role, role)));

    // ... generate token
}
```

### Use in Controllers

```csharp
// Single role
[Authorize(Roles = Roles.Admin)]
[HttpDelete("{id}")]
public async Task<IActionResult> Delete(long id) { }

// Multiple roles (OR logic)
[Authorize(Roles = $"{Roles.Admin},{Roles.Manager}")]
[HttpPut("{id}")]
public async Task<IActionResult> Update(long id) { }

// Stacked attributes (AND logic)
[Authorize(Roles = Roles.Admin)]
[Authorize(Roles = Roles.Manager)]  // Must have BOTH roles
[HttpPost("special")]
public async Task<IActionResult> SpecialAction() { }
```

---

## Policy-Based Authorization

### Permission Requirement

```csharp
// Shared/Authorization/PermissionRequirement.cs
public class PermissionRequirement(string permission) : IAuthorizationRequirement
{
    public string Permission { get; } = permission;
}

// Handler
public class PermissionHandler(
    IPermissionService permissionService
) : AuthorizationHandler<PermissionRequirement>
{
    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        PermissionRequirement requirement)
    {
        var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (string.IsNullOrEmpty(userId))
        {
            context.Fail();
            return;
        }

        var hasPermission = await permissionService.HasPermissionAsync(
            Guid.Parse(userId),
            requirement.Permission);

        if (hasPermission)
        {
            context.Succeed(requirement);
        }
    }
}
```

### Using Policies

```csharp
// Controller level
[Authorize(Policy = "CanManageProducts")]
public class ProductsAdminController : ControllerBase { }

// Action level
[HttpPost]
[Authorize(Policy = "CanManageProducts")]
public async Task<ActionResult<ProductDto>> Create(CreateProductDto dto) { }

// Programmatic check
public class ProductsController(IAuthorizationService authService) : ControllerBase
{
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(long id)
    {
        var result = await authService.AuthorizeAsync(User, "CanManageProducts");

        if (!result.Succeeded)
        {
            return Forbid();
        }

        // Delete logic
    }
}
```

---

## Resource-Based Authorization

For permissions that depend on the specific resource:

```csharp
// Requirement
public class ResourceOwnerRequirement : IAuthorizationRequirement { }

// Handler
public class ResourceOwnerHandler
    : AuthorizationHandler<ResourceOwnerRequirement, IOwnedResource>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        ResourceOwnerRequirement requirement,
        IOwnedResource resource)
    {
        var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (userId is not null && resource.OwnerId.ToString() == userId)
        {
            context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }
}

// Interface for owned resources
public interface IOwnedResource
{
    Guid OwnerId { get; }
}

// Entity implements interface
public class DocumentEntity : BaseEntity<long>, IOwnedResource
{
    public Guid OwnerId { get; set; }
    public string Title { get; set; } = string.Empty;
}
```

### Using Resource Authorization

```csharp
public class DocumentsController(
    IMediator mediator,
    IAuthorizationService authService
) : ControllerBase
{
    [HttpPut("{id}")]
    public async Task<ActionResult<DocumentDto>> Update(
        long id,
        UpdateDocumentDto dto,
        CancellationToken cancellationToken)
    {
        var document = await mediator.Send(new GetDocumentQuery(id), cancellationToken);

        // Check if user owns the document
        var authResult = await authService.AuthorizeAsync(
            User,
            document,
            "MustBeResourceOwner");

        if (!authResult.Succeeded)
        {
            return Forbid();
        }

        // Update logic
        var command = new UpdateDocumentCommand(id, dto);
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }
}
```

---

## Multi-Tenant Authorization

```csharp
// Requirement
public class TenantAccessRequirement : IAuthorizationRequirement { }

// Handler
public class TenantAccessHandler(
    ITenantContext tenantContext
) : AuthorizationHandler<TenantAccessRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        TenantAccessRequirement requirement)
    {
        var userTenantClaim = context.User.FindFirstValue("TenantId");
        var currentTenant = tenantContext.TenantId;

        if (userTenantClaim is not null &&
            Guid.Parse(userTenantClaim) == currentTenant)
        {
            context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }
}
```

---

## Combining Requirements

```csharp
// All requirements must pass (AND logic)
options.AddPolicy("AdminWithProductPermission", policy =>
{
    policy.RequireRole("Admin");
    policy.Requirements.Add(new PermissionRequirement("products:write"));
});

// Custom policy with multiple conditions
options.AddPolicy("ComplexPolicy", policy =>
{
    policy.RequireAuthenticatedUser();
    policy.RequireRole("Manager", "Admin");  // Either role
    policy.RequireClaim("Department", "Sales", "Marketing");  // Either value
    policy.Requirements.Add(new CustomRequirement());
});
```

---

## Permission Service

```csharp
// Contracts/Interfaces/IPermissionService.cs
public interface IPermissionService
{
    Task<bool> HasPermissionAsync(Guid userId, string permission, CancellationToken ct = default);
    Task<IEnumerable<string>> GetPermissionsAsync(Guid userId, CancellationToken ct = default);
}

// Services/PermissionService.cs
public class PermissionService(
    IUserRepository userRepository,
    IMemoryCache cache
) : IPermissionService
{
    public async Task<bool> HasPermissionAsync(
        Guid userId,
        string permission,
        CancellationToken ct = default)
    {
        var permissions = await GetPermissionsAsync(userId, ct);
        return permissions.Contains(permission);
    }

    public async Task<IEnumerable<string>> GetPermissionsAsync(
        Guid userId,
        CancellationToken ct = default)
    {
        var cacheKey = $"permissions:{userId}";

        if (cache.TryGetValue(cacheKey, out IEnumerable<string>? cached))
        {
            return cached!;
        }

        // Get permissions from user's roles
        var permissions = await userRepository.GetPermissionsAsync(userId, ct);

        cache.Set(cacheKey, permissions, TimeSpan.FromMinutes(5));

        return permissions;
    }
}
```

---

## Permission Data Model

```csharp
// Entities
public class RoleEntity
{
    public Guid Id { get; set; }
    public required string Name { get; set; }
    public ICollection<RolePermissionEntity> RolePermissions { get; set; } = [];
}

public class PermissionEntity
{
    public Guid Id { get; set; }
    public required string Name { get; set; }  // e.g., "products:write"
    public string? Description { get; set; }
}

public class RolePermissionEntity
{
    public Guid RoleId { get; set; }
    public Guid PermissionId { get; set; }

    public RoleEntity Role { get; set; } = null!;
    public PermissionEntity Permission { get; set; } = null!;
}

public class UserRoleEntity
{
    public Guid UserId { get; set; }
    public Guid RoleId { get; set; }

    public UserEntity User { get; set; } = null!;
    public RoleEntity Role { get; set; } = null!;
}
```

### Repository Method

```csharp
public async Task<IEnumerable<string>> GetPermissionsAsync(
    Guid userId,
    CancellationToken ct)
{
    return await context.UserRoles
        .AsNoTracking()
        .Where(ur => ur.UserId == userId)
        .SelectMany(ur => ur.Role.RolePermissions)
        .Select(rp => rp.Permission.Name)
        .Distinct()
        .ToListAsync(ct);
}
```

---

## Preload Permissions Filter

Load permissions at the start of request:

```csharp
// Api/Filters/PermissionPreloadFilter.cs
public class PermissionPreloadFilter(IPermissionService permissionService) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        var userId = context.HttpContext.User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (userId is not null)
        {
            // Preload permissions into cache
            await permissionService.GetPermissionsAsync(
                Guid.Parse(userId),
                context.HttpContext.RequestAborted);
        }

        await next();
    }
}

// Registration
builder.Services.AddControllers(options =>
{
    options.Filters.Add<PermissionPreloadFilter>();
});
```

---

## Authorization in Handlers

```csharp
public class UpdateProductCommandHandler(
    IProductRepository repository,
    IAuthorizationService authService,
    IMapper mapper
) : IRequestHandler<UpdateProductCommand, ProductDto>
{
    public async Task<ProductDto> Handle(
        UpdateProductCommand request,
        CancellationToken cancellationToken)
    {
        var product = await repository.GetByIdAsync(request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Product), request.Id);

        // Check authorization
        var authResult = await authService.AuthorizeAsync(
            request.User,
            product,
            "CanEditProduct");

        if (!authResult.Succeeded)
        {
            throw new ForbiddenException("You cannot edit this product.");
        }

        // Update logic
        mapper.Map(request.Dto, product);
        await repository.UpdateAsync(product, cancellationToken);

        return mapper.Map<ProductDto>(product);
    }
}
```

---

## Testing Authorization

```csharp
public class PermissionHandlerTests
{
    [Fact]
    public async Task HandleRequirementAsync_UserHasPermission_Succeeds()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var permission = "products:write";

        var permissionService = new Mock<IPermissionService>();
        permissionService
            .Setup(p => p.HasPermissionAsync(userId, permission, default))
            .ReturnsAsync(true);

        var handler = new PermissionHandler(permissionService.Object);

        var user = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(ClaimTypes.NameIdentifier, userId.ToString())
        ]));

        var context = new AuthorizationHandlerContext(
            [new PermissionRequirement(permission)],
            user,
            null);

        // Act
        await handler.HandleAsync(context);

        // Assert
        context.HasSucceeded.Should().BeTrue();
    }

    [Fact]
    public async Task HandleRequirementAsync_UserLacksPermission_Fails()
    {
        // Arrange
        var permissionService = new Mock<IPermissionService>();
        permissionService
            .Setup(p => p.HasPermissionAsync(It.IsAny<Guid>(), It.IsAny<string>(), default))
            .ReturnsAsync(false);

        var handler = new PermissionHandler(permissionService.Object);

        var context = new AuthorizationHandlerContext(
            [new PermissionRequirement("products:write")],
            new ClaimsPrincipal(new ClaimsIdentity(
            [
                new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString())
            ])),
            null);

        // Act
        await handler.HandleAsync(context);

        // Assert
        context.HasSucceeded.Should().BeFalse();
    }
}
```

---

## Best Practices

### Do

```csharp
// ✅ Use policies for complex authorization
[Authorize(Policy = "CanManageProducts")]

// ✅ Cache permissions
cache.Set(cacheKey, permissions, TimeSpan.FromMinutes(5));

// ✅ Use resource-based auth for ownership checks
await authService.AuthorizeAsync(User, resource, "MustBeOwner")

// ✅ Throw ForbiddenException in handlers
throw new ForbiddenException("You cannot perform this action.");

// ✅ Define permissions granularly
"products:read", "products:write", "products:delete"
```

### Don't

```csharp
// ❌ Hardcode role checks in business logic
if (user.Role == "Admin") { }

// ❌ Skip authorization in handlers
public async Task Handle(Command cmd)
{
    // No auth check - anyone can execute!
}

// ❌ Return 404 for forbidden resources (information leak)
if (!authorized) return NotFound();  // Use Forbid()

// ❌ Overly broad permissions
"admin:all"  // Too powerful
```
