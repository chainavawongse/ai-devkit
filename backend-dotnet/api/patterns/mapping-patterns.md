# Mapping Patterns

AutoMapper configuration and object mapping best practices.

## Setup

```bash
dotnet add package AutoMapper
```

```csharp
// Program.cs
builder.Services.AddAutoMapper(typeof(ProductMappingProfile).Assembly);
```

---

## Basic Mapping Profile

```csharp
// Services/Mapping/ProductMappingProfile.cs
public class ProductMappingProfile : Profile
{
    public ProductMappingProfile()
    {
        // Entity to DTO
        CreateMap<ProductEntity, ProductDto>();

        // DTO to Entity (for creates)
        CreateMap<CreateProductDto, ProductEntity>()
            .ForMember(dest => dest.Id, opt => opt.Ignore())
            .ForMember(dest => dest.CreatedAt, opt => opt.Ignore())
            .ForMember(dest => dest.UpdatedAt, opt => opt.Ignore());

        // DTO to Entity (for updates)
        CreateMap<UpdateProductDto, ProductEntity>()
            .ForMember(dest => dest.Id, opt => opt.Ignore())
            .ForMember(dest => dest.CreatedAt, opt => opt.Ignore());
    }
}
```

---

## Common Mapping Scenarios

### Flattening Nested Objects

```csharp
// Entities
public class OrderEntity
{
    public long Id { get; set; }
    public CustomerEntity Customer { get; set; } = null!;
    public AddressEntity ShippingAddress { get; set; } = null!;
}

// DTO with flattened properties
public class OrderDto
{
    public long Id { get; init; }
    public string CustomerName { get; init; } = string.Empty;
    public string CustomerEmail { get; init; } = string.Empty;
    public string ShippingAddressStreet { get; init; } = string.Empty;
    public string ShippingAddressCity { get; init; } = string.Empty;
}

// AutoMapper flattens by convention:
// Customer.Name -> CustomerName
// ShippingAddress.Street -> ShippingAddressStreet
CreateMap<OrderEntity, OrderDto>();
```

### Custom Member Mapping

```csharp
CreateMap<ProductEntity, ProductDto>()
    // Map from different source property
    .ForMember(dest => dest.ProductName,
        opt => opt.MapFrom(src => src.Name))

    // Computed value
    .ForMember(dest => dest.TotalValue,
        opt => opt.MapFrom(src => src.Quantity * src.UnitPrice))

    // Conditional mapping
    .ForMember(dest => dest.DisplayPrice,
        opt => opt.MapFrom(src =>
            src.IsOnSale ? src.SalePrice : src.Price))

    // Null substitution
    .ForMember(dest => dest.Description,
        opt => opt.NullSubstitute("No description available"));
```

### Ignoring Properties

```csharp
CreateMap<CreateProductDto, ProductEntity>()
    // Ignore specific properties
    .ForMember(dest => dest.Id, opt => opt.Ignore())
    .ForMember(dest => dest.CreatedAt, opt => opt.Ignore())
    .ForMember(dest => dest.CreatedBy, opt => opt.Ignore())

    // Ignore all unmapped properties (use carefully)
    .ForAllMembers(opt => opt.Condition((src, dest, srcMember) =>
        srcMember != null));
```

### Collection Mapping

```csharp
CreateMap<OrderEntity, OrderDto>()
    .ForMember(dest => dest.Items,
        opt => opt.MapFrom(src => src.LineItems));

CreateMap<OrderLineItemEntity, OrderItemDto>();
```

---

## Value Resolvers

For complex mapping logic:

```csharp
// Resolver
public class PriceWithTaxResolver(ITaxService taxService)
    : IValueResolver<ProductEntity, ProductDto, decimal>
{
    public decimal Resolve(
        ProductEntity source,
        ProductDto destination,
        decimal destMember,
        ResolutionContext context)
    {
        return source.Price + taxService.CalculateTax(source.Price, source.TaxCategoryId);
    }
}

// Registration
CreateMap<ProductEntity, ProductDto>()
    .ForMember(dest => dest.PriceWithTax,
        opt => opt.MapFrom<PriceWithTaxResolver>());
```

---

## Type Converters

For complete type transformation:

```csharp
// Converter
public class DateTimeToStringConverter : ITypeConverter<DateTime, string>
{
    public string Convert(
        DateTime source,
        string destination,
        ResolutionContext context)
    {
        return source.ToString("yyyy-MM-dd HH:mm:ss");
    }
}

// Registration
CreateMap<DateTime, string>().ConvertUsing<DateTimeToStringConverter>();
```

---

## Conditional Mapping

```csharp
CreateMap<ProductEntity, ProductDto>()
    // Only map if condition is true
    .ForMember(dest => dest.InternalNotes,
        opt => opt.PreCondition(src => src.IsPublic == false))

    // Map only non-null values
    .ForMember(dest => dest.Description,
        opt => opt.Condition(src => src.Description != null));
```

---

## Reverse Mapping

```csharp
CreateMap<ProductEntity, ProductDto>()
    .ReverseMap()
    .ForMember(dest => dest.Id, opt => opt.Ignore())
    .ForMember(dest => dest.CreatedAt, opt => opt.Ignore());
```

---

## Projection for Queries

Use `ProjectTo` for efficient database queries:

```csharp
// In repository or query handler
public async Task<List<ProductDto>> GetProductsAsync(CancellationToken ct)
{
    return await context.Products
        .AsNoTracking()
        .Where(p => p.IsActive)
        .OrderBy(p => p.Name)
        .ProjectTo<ProductDto>(mapper.ConfigurationProvider)
        .ToListAsync(ct);
}
```

`ProjectTo` generates optimized SQL selecting only needed columns.

---

## Mapping in Handlers

```csharp
public class CreateProductCommandHandler(
    IProductRepository repository,
    IMapper mapper
) : IRequestHandler<CreateProductCommand, ProductDto>
{
    public async Task<ProductDto> Handle(
        CreateProductCommand request,
        CancellationToken cancellationToken)
    {
        // Map DTO to entity
        var entity = mapper.Map<ProductEntity>(request.Dto);

        // Set additional properties not from DTO
        entity.CreatedBy = request.UserId;
        entity.CreatedAt = DateTime.UtcNow;

        await repository.AddAsync(entity, cancellationToken);

        // Map entity back to DTO for response
        return mapper.Map<ProductDto>(entity);
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
        var entity = await repository.GetByIdAsync(request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Product), request.Id);

        // Map DTO onto existing entity (updates in place)
        mapper.Map(request.Dto, entity);

        entity.UpdatedAt = DateTime.UtcNow;
        entity.UpdatedBy = request.UserId;

        await repository.UpdateAsync(entity, cancellationToken);

        return mapper.Map<ProductDto>(entity);
    }
}
```

---

## Enum Mapping

```csharp
// String to enum
CreateMap<string, ProductStatus>()
    .ConvertUsing(src => Enum.Parse<ProductStatus>(src, ignoreCase: true));

// Enum to string
CreateMap<ProductStatus, string>()
    .ConvertUsing(src => src.ToString());

// In profile
CreateMap<ProductEntity, ProductDto>()
    .ForMember(dest => dest.StatusName,
        opt => opt.MapFrom(src => src.Status.ToString()));
```

---

## Inheritance Mapping

```csharp
// Base mapping
CreateMap<OrderEntity, OrderDto>()
    .Include<RegularOrderEntity, RegularOrderDto>()
    .Include<SubscriptionOrderEntity, SubscriptionOrderDto>();

// Derived mappings
CreateMap<RegularOrderEntity, RegularOrderDto>();
CreateMap<SubscriptionOrderEntity, SubscriptionOrderDto>();
```

---

## Profile Organization

```csharp
// Organize by feature
public class ProductMappingProfile : Profile
{
    public ProductMappingProfile()
    {
        CreateProductMappings();
        CreateCategoryMappings();
    }

    private void CreateProductMappings()
    {
        CreateMap<ProductEntity, ProductDto>();
        CreateMap<ProductEntity, ProductDetailDto>();
        CreateMap<CreateProductDto, ProductEntity>();
        CreateMap<UpdateProductDto, ProductEntity>();
    }

    private void CreateCategoryMappings()
    {
        CreateMap<CategoryEntity, CategoryDto>();
    }
}
```

Or separate profiles per aggregate:

```
Services/
└── Mapping/
    ├── ProductMappingProfile.cs
    ├── OrderMappingProfile.cs
    ├── CustomerMappingProfile.cs
    └── CommonMappingProfile.cs
```

---

## Validation

Enable configuration validation to catch errors early:

```csharp
// In tests or startup
var config = new MapperConfiguration(cfg =>
{
    cfg.AddProfile<ProductMappingProfile>();
});

// Throws if mappings are invalid
config.AssertConfigurationIsValid();
```

```csharp
// In test project
public class MappingConfigurationTests
{
    [Fact]
    public void AutoMapper_Configuration_IsValid()
    {
        var config = new MapperConfiguration(cfg =>
        {
            cfg.AddMaps(typeof(ProductMappingProfile).Assembly);
        });

        config.AssertConfigurationIsValid();
    }
}
```

---

## When NOT to Use AutoMapper

### Simple Mappings

```csharp
// For 1-2 properties, manual mapping is clearer
// ❌ Overkill
CreateMap<UserIdDto, Guid>()
    .ConvertUsing(src => src.Id);

// ✅ Just do this
var userId = dto.Id;
```

### Complex Business Logic

```csharp
// ❌ Don't put business logic in mapping
CreateMap<OrderEntity, OrderDto>()
    .ForMember(dest => dest.Total,
        opt => opt.MapFrom(src =>
            CalculateTotalWithDiscountsAndTaxes(src)));  // Too complex

// ✅ Do this in the handler
var dto = mapper.Map<OrderDto>(order);
dto = dto with { Total = orderCalculator.CalculateTotal(order) };
```

### When Types Are Very Different

```csharp
// If source and destination have little in common,
// manual mapping is often clearer
public ProductDetailDto ToDetailDto(ProductEntity entity, IEnumerable<ReviewEntity> reviews)
{
    return new ProductDetailDto
    {
        Id = entity.Id,
        Name = entity.Name,
        Reviews = reviews.Select(r => new ReviewDto { ... }).ToList(),
        AverageRating = reviews.Average(r => r.Rating),
        // ... many computed properties
    };
}
```

---

## Best Practices

### Do

```csharp
// ✅ Use ProjectTo for database queries
.ProjectTo<ProductDto>(mapper.ConfigurationProvider)

// ✅ Validate configuration in tests
config.AssertConfigurationIsValid();

// ✅ Organize profiles by feature/aggregate
public class ProductMappingProfile : Profile

// ✅ Ignore properties explicitly
.ForMember(dest => dest.Id, opt => opt.Ignore())

// ✅ Use value resolvers for complex logic
.ForMember(dest => dest.Tax, opt => opt.MapFrom<TaxResolver>())
```

### Don't

```csharp
// ❌ Map entities directly in controllers
return Ok(mapper.Map<ProductDto>(entity));  // Do this in handler

// ❌ Use AutoMapper for everything
mapper.Map<int>(stringValue);  // Just use int.Parse

// ❌ Complex logic in ForMember
.ForMember(dest => dest.Value,
    opt => opt.MapFrom(src => {
        // 50 lines of code
    }))

// ❌ Ignore all unmapped members blindly
.ForAllMembers(opt => opt.Ignore())  // Hides configuration errors
```
