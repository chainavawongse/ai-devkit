# OData Patterns

Query, filtering, and pagination using OData for read operations.

## Setup

```bash
dotnet add package Microsoft.AspNetCore.OData
```

```csharp
// Program.cs
var modelBuilder = new ODataConventionModelBuilder();
modelBuilder.EntitySet<ProductDto>("Products");
modelBuilder.EntitySet<OrderDto>("Orders");

builder.Services.AddControllers()
    .AddOData(options => options
        .AddRouteComponents("api", modelBuilder.GetEdmModel())
        .Select()
        .Filter()
        .OrderBy()
        .Expand()
        .Count()
        .SetMaxTop(100));
```

---

## Controller Setup

```csharp
[Route("api/[controller]")]
[ApiController]
public class ProductsController(
    IMediator mediator,
    IMapper mapper,
    AppDbContext context
) : ControllerBase
{
    // OData-enabled query endpoint
    [HttpGet]
    [EnableQuery(MaxTop = 100, PageSize = 20)]
    public IQueryable<ProductDto> Get()
    {
        return context.Products
            .AsNoTracking()
            .ProjectTo<ProductDto>(mapper.ConfigurationProvider);
    }

    // Standard CRUD endpoints (non-OData)
    [HttpGet("{id:long}")]
    public async Task<ActionResult<ProductDto>> GetById(
        long id,
        CancellationToken cancellationToken)
    {
        var query = new GetProductByIdQuery(id);
        var result = await mediator.Send(query, cancellationToken);
        return Ok(result);
    }

    [HttpPost]
    public async Task<ActionResult<ProductDto>> Create(
        CreateProductDto dto,
        CancellationToken cancellationToken)
    {
        var command = new CreateProductCommand(dto, UserId);
        var result = await mediator.Send(command, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }
}
```

---

## OData Query Options

### $select - Choose specific fields

```http
GET /api/products?$select=id,name,price
```

Response:
```json
[
  { "id": 1, "name": "Widget", "price": 29.99 },
  { "id": 2, "name": "Gadget", "price": 49.99 }
]
```

### $filter - Filter results

```http
# Comparison operators
GET /api/products?$filter=price gt 100
GET /api/products?$filter=price ge 50 and price le 200
GET /api/products?$filter=status eq 'Active'

# String functions
GET /api/products?$filter=contains(name, 'Widget')
GET /api/products?$filter=startswith(name, 'Pro')
GET /api/products?$filter=endswith(sku, '-001')

# Logical operators
GET /api/products?$filter=price gt 100 and status eq 'Active'
GET /api/products?$filter=categoryId eq 1 or categoryId eq 2

# Null checks
GET /api/products?$filter=description ne null

# Date filtering
GET /api/products?$filter=createdAt gt 2024-01-01
GET /api/products?$filter=year(createdAt) eq 2024
```

### $orderby - Sort results

```http
GET /api/products?$orderby=name
GET /api/products?$orderby=price desc
GET /api/products?$orderby=categoryId,name desc
```

### $top and $skip - Pagination

```http
GET /api/products?$top=10
GET /api/products?$skip=20&$top=10
```

### $count - Include total count

```http
GET /api/products?$count=true
```

Response:
```json
{
  "@odata.count": 150,
  "value": [...]
}
```

### $expand - Include related entities

```http
GET /api/products?$expand=category
GET /api/products?$expand=category,supplier
GET /api/products?$expand=orderItems($filter=quantity gt 5)
```

---

## Combined Queries

```http
GET /api/products?$filter=status eq 'Active' and price gt 50&$orderby=name&$top=20&$skip=0&$count=true&$select=id,name,price,category&$expand=category($select=id,name)
```

---

## DTO Configuration for OData

```csharp
public class ProductDto
{
    public long Id { get; init; }
    public required string Name { get; init; }
    public required string Sku { get; init; }
    public decimal Price { get; init; }
    public string? Description { get; init; }
    public ProductStatus Status { get; init; }
    public DateTime CreatedAt { get; init; }

    // Navigation property for $expand
    public CategoryDto? Category { get; init; }
}

public class CategoryDto
{
    public long Id { get; init; }
    public required string Name { get; init; }
}
```

---

## AutoMapper Projection

Use `ProjectTo` for efficient SQL generation:

```csharp
// Mapping profile
public class ProductMappingProfile : Profile
{
    public ProductMappingProfile()
    {
        CreateMap<ProductEntity, ProductDto>();
        CreateMap<CategoryEntity, CategoryDto>();
    }
}

// Controller
[HttpGet]
[EnableQuery]
public IQueryable<ProductDto> Get()
{
    return context.Products
        .AsNoTracking()
        .ProjectTo<ProductDto>(mapper.ConfigurationProvider);
}
```

This generates efficient SQL with only requested columns.

---

## Limiting OData Features

### Per-Endpoint Control

```csharp
// Allow only specific operations
[EnableQuery(
    AllowedQueryOptions = AllowedQueryOptions.Filter |
                          AllowedQueryOptions.OrderBy |
                          AllowedQueryOptions.Top |
                          AllowedQueryOptions.Skip,
    MaxTop = 50,
    PageSize = 20)]
public IQueryable<ProductDto> Get() { }

// Restrict filterable/sortable properties
[EnableQuery(
    AllowedOrderByProperties = "Name,Price,CreatedAt",
    AllowedArithmeticOperators = AllowedArithmeticOperators.None)]
public IQueryable<ProductDto> Get() { }
```

### Global Configuration

```csharp
builder.Services.AddControllers()
    .AddOData(options => options
        .AddRouteComponents("api", modelBuilder.GetEdmModel())
        .Select()
        .Filter()
        .OrderBy()
        .Count()
        .SetMaxTop(100)  // Global max
        .EnableQueryFeatures(50));  // Default page size
```

---

## Custom Query Handling

### Pre-filtering (Security)

```csharp
[HttpGet]
[EnableQuery]
public IQueryable<ProductDto> Get()
{
    var customerId = GetCustomerId();

    // Pre-filter before OData processes
    return context.Products
        .AsNoTracking()
        .Where(p => p.CustomerId == customerId)  // Security filter
        .Where(p => !p.IsDeleted)                // Soft delete filter
        .ProjectTo<ProductDto>(mapper.ConfigurationProvider);
}
```

### Post-processing

```csharp
[HttpGet]
[EnableQuery]
public IQueryable<ProductDto> Get(ODataQueryOptions<ProductDto> options)
{
    var query = context.Products
        .AsNoTracking()
        .ProjectTo<ProductDto>(mapper.ConfigurationProvider);

    // Log the query for debugging
    var sql = options.ApplyTo(query).ToQueryString();
    logger.LogDebug("OData Query: {Sql}", sql);

    return query;
}
```

---

## OData with CQRS

For complex queries, delegate to a query handler:

```csharp
// Keep OData for simple list queries
[HttpGet]
[EnableQuery]
public IQueryable<ProductDto> Get() { }

// Use CQRS for complex operations
[HttpGet("search")]
public async Task<ActionResult<SearchResultDto>> Search(
    [FromQuery] ProductSearchQuery query,
    CancellationToken cancellationToken)
{
    var result = await mediator.Send(query, cancellationToken);
    return Ok(result);
}

// Use CQRS for aggregations
[HttpGet("stats")]
public async Task<ActionResult<ProductStatsDto>> GetStats(
    CancellationToken cancellationToken)
{
    var query = new GetProductStatsQuery();
    var result = await mediator.Send(query, cancellationToken);
    return Ok(result);
}
```

---

## Pagination Response

### Standard OData Response

```json
{
  "@odata.context": "https://api.example.com/api/$metadata#Products",
  "@odata.count": 150,
  "@odata.nextLink": "https://api.example.com/api/Products?$skip=20",
  "value": [
    { "id": 1, "name": "Widget", "price": 29.99 },
    { "id": 2, "name": "Gadget", "price": 49.99 }
  ]
}
```

### Custom Pagination Wrapper

```csharp
public class PagedResult<T>
{
    public IEnumerable<T> Items { get; init; } = [];
    public int TotalCount { get; init; }
    public int Page { get; init; }
    public int PageSize { get; init; }
    public int TotalPages => (int)Math.Ceiling(TotalCount / (double)PageSize);
    public bool HasNextPage => Page < TotalPages;
    public bool HasPreviousPage => Page > 1;
}

// Custom endpoint if OData format isn't desired
[HttpGet("paged")]
public async Task<ActionResult<PagedResult<ProductDto>>> GetPaged(
    [FromQuery] int page = 1,
    [FromQuery] int pageSize = 20,
    [FromQuery] string? search = null,
    CancellationToken cancellationToken = default)
{
    var query = context.Products.AsNoTracking();

    if (!string.IsNullOrWhiteSpace(search))
    {
        query = query.Where(p => p.Name.Contains(search));
    }

    var totalCount = await query.CountAsync(cancellationToken);

    var items = await query
        .OrderBy(p => p.Name)
        .Skip((page - 1) * pageSize)
        .Take(pageSize)
        .ProjectTo<ProductDto>(mapper.ConfigurationProvider)
        .ToListAsync(cancellationToken);

    return Ok(new PagedResult<ProductDto>
    {
        Items = items,
        TotalCount = totalCount,
        Page = page,
        PageSize = pageSize
    });
}
```

---

## Error Handling

```csharp
// Handle OData parsing errors
builder.Services.AddControllers(options =>
{
    options.Filters.Add<ODataExceptionFilter>();
});

public class ODataExceptionFilter : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        if (context.Exception is ODataException odataEx)
        {
            context.Result = new BadRequestObjectResult(new ProblemDetails
            {
                Title = "Invalid OData Query",
                Status = 400,
                Detail = odataEx.Message
            });
            context.ExceptionHandled = true;
        }
    }
}
```

---

## Performance Considerations

### Indexing

Ensure database indexes match common filter patterns:

```csharp
// Entity configuration
public class ProductEntityConfiguration : IEntityTypeConfiguration<ProductEntity>
{
    public void Configure(EntityTypeBuilder<ProductEntity> builder)
    {
        // Index for common filters
        builder.HasIndex(p => p.Status);
        builder.HasIndex(p => p.CategoryId);
        builder.HasIndex(p => p.CreatedAt);
        builder.HasIndex(p => p.Name);

        // Composite index for common query patterns
        builder.HasIndex(p => new { p.Status, p.CategoryId });
    }
}
```

### Query Limits

```csharp
[EnableQuery(
    MaxTop = 100,           // Limit max results
    MaxExpansionDepth = 2,  // Limit $expand depth
    MaxAnyAllExpressionDepth = 2,
    MaxNodeCount = 100)]    // Limit query complexity
```

---

## Best Practices

### Do

```csharp
// ✅ Use ProjectTo for efficient queries
.ProjectTo<ProductDto>(mapper.ConfigurationProvider)

// ✅ Apply security filters before OData
.Where(p => p.CustomerId == customerId)

// ✅ Use AsNoTracking for read-only queries
.AsNoTracking()

// ✅ Set reasonable limits
[EnableQuery(MaxTop = 100, PageSize = 20)]

// ✅ Index commonly filtered columns
builder.HasIndex(p => p.Status);
```

### Don't

```csharp
// ❌ Expose entities directly
[EnableQuery]
public IQueryable<ProductEntity> Get()  // Exposes database schema

// ❌ Allow unlimited results
[EnableQuery]  // No MaxTop set

// ❌ Complex computed properties in DTOs (can't translate to SQL)
public string FullName => $"{FirstName} {LastName}";

// ❌ Skip security checks
public IQueryable<ProductDto> Get()
{
    return context.Products.ProjectTo...  // No customer filter!
}
```
