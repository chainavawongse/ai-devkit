# Naming Conventions

Consistent naming rules for files, classes, methods, and C# code style.

## Files & Folders

### Projects

```
✅ PascalCase with dots for namespacing
MyApp.Api
MyApp.Services
MyApp.Contracts
MyApp.Data
MyApp.Shared
MyApp.Tests.Unit
```

### Folders

```
✅ PascalCase for code folders
Controllers/
Handlers/
Repositories/
Entities/

✅ Lowercase for non-code folders
src/
tests/
docs/
```

### Files

```csharp
// Controllers
ProductsController.cs           // ✅ Plural noun + Controller

// Handlers
CreateProductCommandHandler.cs  // ✅ Command/Query name + Handler
GetProductByIdQueryHandler.cs

// Commands & Queries
CreateProductCommand.cs         // ✅ Verb + Entity + Command
UpdateProductCommand.cs
DeleteProductCommand.cs
GetProductByIdQuery.cs          // ✅ Get + Entity + Query
GetProductsQuery.cs

// DTOs
CreateProductDto.cs             // ✅ Verb + Entity + Dto
UpdateProductDto.cs
PatchProductDto.cs
ProductDto.cs                   // ✅ Entity + Dto (response)
ProductDetailDto.cs

// Entities
ProductEntity.cs                // ✅ Entity + Entity suffix
OrderEntity.cs
UserEntity.cs

// Repositories
ProductRepository.cs            // ✅ Entity + Repository
IProductRepository.cs           // ✅ I + Entity + Repository

// Services
ProductAccessService.cs         // ✅ Descriptive + Service
ProductPersistenceService.cs
IProductAccessService.cs

// Validators
CreateProductDtoValidator.cs    // ✅ DTO name + Validator
UpdateProductDtoValidator.cs

// Configurations
ProductEntityConfiguration.cs   // ✅ Entity + Configuration

// Tests
CreateProductCommandHandlerTests.cs  // ✅ Subject + Tests
ProductRepositoryTests.cs
```

---

## Classes & Types

### Classes

```csharp
// ✅ PascalCase, noun-based
public class ProductService { }
public class OrderRepository { }
public class CreateProductCommandHandler { }

// ✅ Suffix indicates purpose
public class ProductController { }       // Controller
public class ProductService { }          // Service
public class ProductRepository { }       // Repository
public class ProductEntity { }           // Entity
public class ProductDto { }              // DTO
public class ProductValidator { }        // Validator
```

### Interfaces

```csharp
// ✅ Prefix with I
public interface IProductRepository { }
public interface IProductService { }
public interface IEmailSender { }

// ❌ Don't use I for non-interfaces
public class IProductHelper { }  // Wrong
```

### Records

```csharp
// ✅ Commands: Verb + Entity + Command
public record CreateProductCommand(CreateProductDto Dto, Guid UserId) : IRequest<ProductDto>;
public record UpdateProductCommand(long Id, UpdateProductDto Dto, Guid UserId) : IRequest<ProductDto>;
public record DeleteProductCommand(long Id, Guid UserId) : IRequest;

// ✅ Queries: Get + Entity + Query
public record GetProductByIdQuery(long Id) : IRequest<ProductDto>;
public record GetProductsQuery(ProductFilter? Filter) : IRequest<IEnumerable<ProductDto>>;

// ✅ DTOs: Purpose + Entity + Dto
public record CreateProductDto(string Name, decimal Price);
public record ProductDto(long Id, string Name, decimal Price);
```

### Enums

```csharp
// ✅ Singular PascalCase
public enum ProductStatus
{
    Draft,
    Active,
    Discontinued,
    Archived
}

public enum OrderState
{
    Pending,
    Processing,
    Shipped,
    Delivered,
    Cancelled
}

// ❌ Don't pluralize
public enum ProductStatuses { }  // Wrong
```

### Generic Type Parameters

```csharp
// ✅ T prefix for single parameter
public interface IRepository<TEntity> { }

// ✅ Descriptive names for multiple parameters
public interface IRepository<TKey, TEntity> { }
public class Result<TValue, TError> { }
```

---

## Methods

### Naming Patterns

```csharp
// ✅ Verb-based, describes action
public async Task<Product> GetByIdAsync(long id) { }
public async Task CreateAsync(Product product) { }
public async Task UpdateAsync(Product product) { }
public async Task DeleteAsync(long id) { }
public bool Validate(ProductDto dto) { }

// ✅ Async suffix for async methods
public async Task<Product> GetProductAsync() { }
public async Task SaveChangesAsync() { }

// ✅ Boolean methods: Is, Has, Can, Should
public bool IsValid() { }
public bool HasPermission(string permission) { }
public bool CanExecute() { }
public bool ShouldProcess() { }

// ✅ Try pattern for fallible operations
public bool TryParse(string input, out Product product) { }
public bool TryGetValue(string key, out string value) { }
```

### Handler Methods

```csharp
// ✅ Always named Handle
public async Task<ProductDto> Handle(
    CreateProductCommand request,
    CancellationToken cancellationToken)
{ }
```

### Controller Actions

```csharp
// ✅ Match HTTP semantics
[HttpGet]
public async Task<ActionResult<IEnumerable<ProductDto>>> GetAll() { }

[HttpGet("{id}")]
public async Task<ActionResult<ProductDto>> GetById(long id) { }

[HttpPost]
public async Task<ActionResult<ProductDto>> Create(CreateProductDto dto) { }

[HttpPut("{id}")]
public async Task<ActionResult<ProductDto>> Update(long id, UpdateProductDto dto) { }

[HttpPatch("{id}")]
public async Task<ActionResult<ProductDto>> Patch(long id, PatchProductDto dto) { }

[HttpDelete("{id}")]
public async Task<IActionResult> Delete(long id) { }

// ✅ Custom actions: verb-based
[HttpPost("{id}/submit")]
public async Task<ActionResult<OrderDto>> Submit(long id) { }

[HttpPost("{id}/cancel")]
public async Task<ActionResult<OrderDto>> Cancel(long id) { }
```

---

## Variables & Fields

### Local Variables

```csharp
// ✅ camelCase
var productName = "Widget";
var orderItems = new List<OrderItem>();
var isActive = true;

// ✅ Meaningful names
var product = await repository.GetByIdAsync(id);  // Good
var p = await repository.GetByIdAsync(id);        // Too short

// ✅ Boolean prefixes
var isValid = true;
var hasAccess = false;
var canEdit = user.IsAdmin;
var shouldNotify = order.RequiresNotification;
```

### Private Fields

```csharp
// ✅ _camelCase with underscore prefix
private readonly IProductRepository _repository;
private readonly ILogger<ProductService> _logger;
private readonly ProductSettings _settings;

// ✅ Or use primary constructors (no fields needed)
public class ProductService(
    IProductRepository repository,
    ILogger<ProductService> logger)
```

### Constants

```csharp
// ✅ PascalCase for public constants
public const string DefaultCategory = "General";
public const int MaxPageSize = 100;

// ✅ PascalCase for private constants too
private const int DefaultTimeout = 30;
```

### Static Readonly

```csharp
// ✅ PascalCase
public static readonly TimeSpan DefaultTimeout = TimeSpan.FromSeconds(30);
private static readonly string[] AllowedExtensions = [".jpg", ".png", ".gif"];
```

---

## Parameters

```csharp
// ✅ camelCase
public async Task<Product> GetByIdAsync(long productId, CancellationToken cancellationToken)

// ✅ Descriptive names
public void SendEmail(string recipientEmail, string subject, string body)

// ✅ CancellationToken always last
public async Task ProcessAsync(Order order, CancellationToken cancellationToken)

// ✅ Use ct as abbreviation only for short methods
public async Task<T> GetAsync(CancellationToken ct) => ...
```

---

## Properties

```csharp
// ✅ PascalCase
public string Name { get; set; }
public decimal Price { get; set; }
public DateTime CreatedAt { get; set; }

// ✅ Boolean properties: Is, Has, Can
public bool IsActive { get; set; }
public bool HasDiscount { get; set; }
public bool CanEdit { get; set; }

// ✅ Collection properties: plural
public ICollection<OrderItem> Items { get; set; }
public IReadOnlyList<string> Tags { get; set; }
```

---

## Database & Entities

### Table Names

```csharp
// ✅ Lowercase with underscores (PostgreSQL convention)
builder.ToTable("products");
builder.ToTable("order_items");
builder.ToTable("user_roles");
```

### Column Names

```csharp
// ✅ Lowercase with underscores
builder.Property(p => p.ProductName).HasColumnName("product_name");
builder.Property(p => p.CreatedAt).HasColumnName("created_at");
```

### Entity Configuration

```csharp
// Entity uses PascalCase
public class ProductEntity
{
    public long Id { get; set; }
    public string ProductName { get; set; }  // PascalCase in C#
    public DateTime CreatedAt { get; set; }
}

// Configuration maps to snake_case
public void Configure(EntityTypeBuilder<ProductEntity> builder)
{
    builder.ToTable("products");
    builder.Property(p => p.ProductName).HasColumnName("product_name");
    builder.Property(p => p.CreatedAt).HasColumnName("created_at");
}
```

---

## C# Code Style

### Prefer Expression Bodies for Simple Members

```csharp
// ✅ Expression body for simple getters
public string FullName => $"{FirstName} {LastName}";
public bool IsExpired => ExpiresAt < DateTime.UtcNow;

// ✅ Expression body for simple methods
public override string ToString() => $"{Name} ({Id})";

// ✅ Use block body for complex logic
public decimal CalculateTotal()
{
    var subtotal = Items.Sum(i => i.Price * i.Quantity);
    var tax = subtotal * TaxRate;
    return subtotal + tax;
}
```

### Use Primary Constructors

```csharp
// ✅ Primary constructor (C# 12)
public class ProductService(
    IProductRepository repository,
    IMapper mapper,
    ILogger<ProductService> logger)
{
    public async Task<ProductDto> GetByIdAsync(long id)
    {
        var product = await repository.GetByIdAsync(id);
        return mapper.Map<ProductDto>(product);
    }
}

// ❌ Traditional (more verbose)
public class ProductService
{
    private readonly IProductRepository _repository;
    private readonly IMapper _mapper;

    public ProductService(IProductRepository repository, IMapper mapper)
    {
        _repository = repository;
        _mapper = mapper;
    }
}
```

### Use Target-Typed New

```csharp
// ✅ Target-typed new
List<Product> products = new();
Dictionary<string, int> counts = new();
ProductDto dto = new() { Name = "Widget" };

// ❌ Redundant type specification
List<Product> products = new List<Product>();
```

### Use Collection Expressions

```csharp
// ✅ Collection expressions (C# 12)
int[] numbers = [1, 2, 3, 4, 5];
List<string> names = ["Alice", "Bob", "Charlie"];
string[] empty = [];

// ✅ Spread operator
int[] combined = [..firstArray, ..secondArray];
```

### Use Pattern Matching

```csharp
// ✅ Switch expressions
var message = status switch
{
    OrderStatus.Pending => "Waiting for processing",
    OrderStatus.Shipped => "On the way",
    OrderStatus.Delivered => "Received",
    _ => "Unknown status"
};

// ✅ Property patterns
if (order is { Status: OrderStatus.Pending, Total: > 100 })
{
    // High-value pending order
}

// ✅ Type patterns
if (exception is EntityNotFoundException notFound)
{
    logger.LogWarning("Entity not found: {Type} {Id}", notFound.EntityType, notFound.EntityId);
}
```

### Prefer Records for DTOs

```csharp
// ✅ Records for immutable DTOs
public record ProductDto(long Id, string Name, decimal Price);

public record CreateProductDto
{
    public required string Name { get; init; }
    public required decimal Price { get; init; }
    public string? Description { get; init; }
}

// ❌ Classes for simple DTOs
public class ProductDto
{
    public long Id { get; set; }
    public string Name { get; set; }
    public decimal Price { get; set; }
}
```

### Null Handling

```csharp
// ✅ Null-conditional operator
var length = name?.Length ?? 0;
var city = user?.Address?.City;

// ✅ Null-coalescing assignment
items ??= new List<Item>();

// ✅ Required members
public record CreateProductDto
{
    public required string Name { get; init; }  // Must be set
    public string? Description { get; init; }   // Optional
}

// ✅ ArgumentNullException.ThrowIfNull
public void Process(Order order)
{
    ArgumentNullException.ThrowIfNull(order);
}
```

---

## Quick Reference

| Element | Convention | Example |
|---------|------------|---------|
| Project | PascalCase.Dots | `MyApp.Services` |
| Folder | PascalCase | `Controllers/` |
| File | PascalCase | `ProductService.cs` |
| Class | PascalCase | `ProductService` |
| Interface | IPascalCase | `IProductService` |
| Record | PascalCase | `CreateProductCommand` |
| Enum | PascalCase (singular) | `OrderStatus` |
| Method | PascalCase | `GetByIdAsync` |
| Async Method | PascalCaseAsync | `GetProductAsync` |
| Property | PascalCase | `ProductName` |
| Field (private) | _camelCase | `_repository` |
| Variable | camelCase | `productName` |
| Parameter | camelCase | `productId` |
| Constant | PascalCase | `MaxPageSize` |
| Table | snake_case | `order_items` |
| Column | snake_case | `created_at` |

---

## Anti-Patterns

```csharp
// ❌ Abbreviations (unless universal)
var prod = GetProduct();           // Use: product
var qty = item.Quantity;           // Use: quantity
var mgr = new ProductManager();    // Use: manager

// ❌ Hungarian notation
string strName;                    // Use: name
int intCount;                      // Use: count

// ❌ Underscores in public members
public string Product_Name;        // Use: ProductName

// ❌ Generic names
var data = GetData();              // Use: products, orders, etc.
var result = Process();            // Use: validationResult, etc.
var temp = Calculate();            // Use: subtotal, etc.

// ❌ Method names without verbs
public Product Product(long id);   // Use: GetProduct

// ❌ Boolean without prefix
public bool Active { get; set; }   // Use: IsActive
public bool Error { get; set; }    // Use: HasError
```
