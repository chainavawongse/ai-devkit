# Entity Framework Core

Best practices, common gotchas, repository patterns, and PostgreSQL extensions.

## Setup

```bash
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add package Microsoft.EntityFrameworkCore.Design
```

```csharp
// Program.cs
builder.Services.AddDbContext<AppDbContext>(options =>
{
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection"));
});
```

---

## DbContext Configuration

```csharp
// Data/AppDbContext.cs
public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<ProductEntity> Products => Set<ProductEntity>();
    public DbSet<CategoryEntity> Categories => Set<CategoryEntity>();
    public DbSet<OrderEntity> Orders => Set<OrderEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Apply all configurations from assembly
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

        // Global query filter for soft delete
        modelBuilder.Entity<ProductEntity>()
            .HasQueryFilter(p => p.DeletedAt == null);
    }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        // Development-only logging
        #if DEBUG
        optionsBuilder.EnableSensitiveDataLogging();
        optionsBuilder.EnableDetailedErrors();
        #endif
    }
}
```

---

## Entity Configuration

```csharp
// Data/Configurations/ProductEntityConfiguration.cs
public class ProductEntityConfiguration : IEntityTypeConfiguration<ProductEntity>
{
    public void Configure(EntityTypeBuilder<ProductEntity> builder)
    {
        builder.ToTable("products");

        builder.HasKey(p => p.Id);

        builder.Property(p => p.Id)
            .UseIdentityAlwaysColumn();  // PostgreSQL identity

        builder.Property(p => p.Name)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(p => p.Sku)
            .IsRequired()
            .HasMaxLength(50);

        builder.Property(p => p.Price)
            .HasPrecision(18, 2);

        builder.Property(p => p.Description)
            .HasMaxLength(2000);

        builder.Property(p => p.Status)
            .HasConversion<string>()  // Store enum as string
            .HasMaxLength(50);

        // Indexes
        builder.HasIndex(p => p.Sku)
            .IsUnique();

        builder.HasIndex(p => p.Status);

        builder.HasIndex(p => p.CategoryId);

        builder.HasIndex(p => new { p.Status, p.CategoryId });

        // Relationships
        builder.HasOne(p => p.Category)
            .WithMany(c => c.Products)
            .HasForeignKey(p => p.CategoryId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
```

---

## Base Entity

```csharp
// Data/Entities/BaseEntity.cs
public abstract class BaseEntity<TKey>
{
    public TKey Id { get; set; } = default!;
    public DateTime CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
}

public abstract class SoftDeletableEntity<TKey> : BaseEntity<TKey>
{
    public DateTime? DeletedAt { get; set; }
    public Guid? DeletedBy { get; set; }
    public bool IsDeleted => DeletedAt.HasValue;
}
```

---

## Repository Pattern

### Generic Repository

```csharp
// Contracts/Interfaces/IRepository.cs
public interface IRepository<TKey, TEntity> where TEntity : BaseEntity<TKey>
{
    IQueryable<TEntity> Query();
    IQueryable<TEntity> QueryForUpdate();
    Task<TEntity?> GetByIdAsync(TKey id, CancellationToken ct = default);
    Task<TEntity?> GetByIdForUpdateAsync(TKey id, CancellationToken ct = default);
    Task AddAsync(TEntity entity, CancellationToken ct = default);
    Task AddRangeAsync(IEnumerable<TEntity> entities, CancellationToken ct = default);
    void Update(TEntity entity);
    void Remove(TEntity entity);
    Task<bool> ExistsAsync(TKey id, CancellationToken ct = default);
    Task SaveChangesAsync(CancellationToken ct = default);
}

// Data/Repositories/Repository.cs
public class Repository<TKey, TEntity>(AppDbContext context)
    : IRepository<TKey, TEntity>
    where TEntity : BaseEntity<TKey>
{
    protected readonly AppDbContext Context = context;
    protected readonly DbSet<TEntity> DbSet = context.Set<TEntity>();

    // Read-only queries (no tracking)
    public IQueryable<TEntity> Query()
        => DbSet.AsNoTracking();

    // Tracked queries (for updates)
    public IQueryable<TEntity> QueryForUpdate()
        => DbSet.AsTracking();

    public async Task<TEntity?> GetByIdAsync(TKey id, CancellationToken ct = default)
        => await DbSet.AsNoTracking().FirstOrDefaultAsync(e => e.Id!.Equals(id), ct);

    public async Task<TEntity?> GetByIdForUpdateAsync(TKey id, CancellationToken ct = default)
        => await DbSet.FirstOrDefaultAsync(e => e.Id!.Equals(id), ct);

    public async Task AddAsync(TEntity entity, CancellationToken ct = default)
    {
        await DbSet.AddAsync(entity, ct);
        await Context.SaveChangesAsync(ct);
    }

    public async Task AddRangeAsync(IEnumerable<TEntity> entities, CancellationToken ct = default)
    {
        await DbSet.AddRangeAsync(entities, ct);
        await Context.SaveChangesAsync(ct);
    }

    public void Update(TEntity entity)
    {
        DbSet.Update(entity);
    }

    public void Remove(TEntity entity)
    {
        DbSet.Remove(entity);
    }

    public async Task<bool> ExistsAsync(TKey id, CancellationToken ct = default)
        => await DbSet.AnyAsync(e => e.Id!.Equals(id), ct);

    public async Task SaveChangesAsync(CancellationToken ct = default)
        => await Context.SaveChangesAsync(ct);
}
```

### Specific Repository

```csharp
// Contracts/Interfaces/IProductRepository.cs
public interface IProductRepository : IRepository<long, ProductEntity>
{
    Task<ProductEntity?> GetBySkuAsync(string sku, CancellationToken ct = default);
    Task<bool> ExistsBySkuAsync(string sku, CancellationToken ct = default);
    Task<IEnumerable<ProductEntity>> GetByCategoryAsync(long categoryId, CancellationToken ct = default);
}

// Data/Repositories/ProductRepository.cs
public class ProductRepository(AppDbContext context)
    : Repository<long, ProductEntity>(context), IProductRepository
{
    public async Task<ProductEntity?> GetBySkuAsync(string sku, CancellationToken ct = default)
    {
        return await Query()
            .FirstOrDefaultAsync(p => p.Sku == sku, ct);
    }

    public async Task<bool> ExistsBySkuAsync(string sku, CancellationToken ct = default)
    {
        return await Query()
            .AnyAsync(p => p.Sku == sku, ct);
    }

    public async Task<IEnumerable<ProductEntity>> GetByCategoryAsync(
        long categoryId,
        CancellationToken ct = default)
    {
        return await Query()
            .Where(p => p.CategoryId == categoryId)
            .OrderBy(p => p.Name)
            .ToListAsync(ct);
    }
}
```

---

## Best Practices

### Use AsNoTracking for Read-Only Queries

```csharp
// ✅ Good - no tracking overhead
var products = await context.Products
    .AsNoTracking()
    .Where(p => p.IsActive)
    .ToListAsync(ct);

// ❌ Bad - unnecessary tracking
var products = await context.Products
    .Where(p => p.IsActive)
    .ToListAsync(ct);
```

### Use Projections to Select Only Needed Columns

```csharp
// ✅ Good - only fetches needed columns
var productNames = await context.Products
    .AsNoTracking()
    .Select(p => new { p.Id, p.Name, p.Price })
    .ToListAsync(ct);

// ✅ With AutoMapper ProjectTo
var dtos = await context.Products
    .AsNoTracking()
    .ProjectTo<ProductDto>(mapper.ConfigurationProvider)
    .ToListAsync(ct);

// ❌ Bad - fetches all columns
var products = await context.Products.ToListAsync(ct);
var names = products.Select(p => p.Name);
```

### Use AsSplitQuery for Multiple Includes

```csharp
// ✅ Good - prevents cartesian explosion
var orders = await context.Orders
    .AsNoTracking()
    .Include(o => o.LineItems)
    .Include(o => o.Customer)
    .AsSplitQuery()
    .ToListAsync(ct);

// ❌ Can cause cartesian explosion with large datasets
var orders = await context.Orders
    .Include(o => o.LineItems)  // 100 items
    .Include(o => o.Payments)   // 5 payments
    // = 500 rows returned!
    .ToListAsync(ct);
```

### Use Bulk Operations

```csharp
// ✅ Good - single SQL statement
await context.Products
    .Where(p => p.CategoryId == oldCategoryId)
    .ExecuteUpdateAsync(s => s
        .SetProperty(p => p.CategoryId, newCategoryId)
        .SetProperty(p => p.UpdatedAt, DateTime.UtcNow), ct);

await context.Products
    .Where(p => p.IsExpired)
    .ExecuteDeleteAsync(ct);

// ❌ Bad - loads all entities, multiple roundtrips
var products = await context.Products
    .Where(p => p.CategoryId == oldCategoryId)
    .ToListAsync(ct);

foreach (var product in products)
{
    product.CategoryId = newCategoryId;
}
await context.SaveChangesAsync(ct);
```

### Always Pass CancellationToken

```csharp
// ✅ Good
await context.Products.ToListAsync(cancellationToken);
await context.SaveChangesAsync(cancellationToken);

// ❌ Bad
await context.Products.ToListAsync();
```

---

## Common Gotchas

### N+1 Query Problem

```csharp
// ❌ BAD - N+1 queries (1 for orders + N for customers)
var orders = await context.Orders.ToListAsync(ct);
foreach (var order in orders)
{
    Console.WriteLine(order.Customer.Name);  // Lazy load each customer
}

// ✅ GOOD - Eager load
var orders = await context.Orders
    .Include(o => o.Customer)
    .ToListAsync(ct);
```

### Cartesian Explosion

```csharp
// ❌ BAD - if Order has 100 items and 10 payments = 1000 rows
var order = await context.Orders
    .Include(o => o.LineItems)
    .Include(o => o.Payments)
    .FirstOrDefaultAsync(o => o.Id == id, ct);

// ✅ GOOD - Split into separate queries
var order = await context.Orders
    .Include(o => o.LineItems)
    .Include(o => o.Payments)
    .AsSplitQuery()
    .FirstOrDefaultAsync(o => o.Id == id, ct);
```

### No Implicit Transaction on Bulk Operations

```csharp
// ❌ BAD - no transaction, partial updates possible
await context.Products
    .Where(p => p.CategoryId == 1)
    .ExecuteUpdateAsync(s => s.SetProperty(p => p.Status, "Active"), ct);

await context.Products
    .Where(p => p.CategoryId == 2)
    .ExecuteUpdateAsync(s => s.SetProperty(p => p.Status, "Active"), ct);

// ✅ GOOD - explicit transaction
await using var transaction = await context.Database.BeginTransactionAsync(ct);

await context.Products
    .Where(p => p.CategoryId == 1)
    .ExecuteUpdateAsync(s => s.SetProperty(p => p.Status, "Active"), ct);

await context.Products
    .Where(p => p.CategoryId == 2)
    .ExecuteUpdateAsync(s => s.SetProperty(p => p.Status, "Active"), ct);

await transaction.CommitAsync(ct);
```

### Detached Entity Updates

```csharp
// ❌ BAD - entity not tracked, throws or creates new
var product = new ProductEntity { Id = 1, Name = "Updated" };
context.Products.Update(product);  // Marks ALL properties as modified

// ✅ GOOD - fetch then update
var product = await context.Products.FindAsync(id);
product.Name = "Updated";
await context.SaveChangesAsync(ct);

// ✅ Or use ExecuteUpdateAsync
await context.Products
    .Where(p => p.Id == id)
    .ExecuteUpdateAsync(s => s.SetProperty(p => p.Name, "Updated"), ct);
```

### String Contains Performance

```csharp
// ❌ BAD - case-sensitive, no index usage
.Where(p => p.Name.Contains(search))

// ✅ GOOD - case-insensitive with index support (PostgreSQL)
.Where(p => EF.Functions.ILike(p.Name, $"%{search}%"))

// ✅ Or use full-text search for better performance
.Where(p => p.SearchVector.Matches(EF.Functions.ToTsQuery(search)))
```

---

## Soft Delete Pattern

```csharp
// Entity
public class ProductEntity : SoftDeletableEntity<long>
{
    public string Name { get; set; } = string.Empty;
}

// Global query filter (in DbContext)
modelBuilder.Entity<ProductEntity>()
    .HasQueryFilter(p => p.DeletedAt == null);

// Soft delete
public async Task SoftDeleteAsync(long id, Guid userId, CancellationToken ct)
{
    await context.Products
        .Where(p => p.Id == id)
        .ExecuteUpdateAsync(s => s
            .SetProperty(p => p.DeletedAt, DateTime.UtcNow)
            .SetProperty(p => p.DeletedBy, userId), ct);
}

// Query including deleted (bypass filter)
var allProducts = await context.Products
    .IgnoreQueryFilters()
    .ToListAsync(ct);

// Hard delete
public async Task HardDeleteAsync(long id, CancellationToken ct)
{
    await context.Products
        .IgnoreQueryFilters()
        .Where(p => p.Id == id)
        .ExecuteDeleteAsync(ct);
}
```

---

## Audit Interceptor

```csharp
// Data/Interceptors/AuditInterceptor.cs
public class AuditInterceptor(IAuditContext auditContext) : SaveChangesInterceptor
{
    public override InterceptionResult<int> SavingChanges(
        DbContextEventData eventData,
        InterceptionResult<int> result)
    {
        UpdateAuditFields(eventData.Context);
        return base.SavingChanges(eventData, result);
    }

    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData,
        InterceptionResult<int> result,
        CancellationToken cancellationToken = default)
    {
        UpdateAuditFields(eventData.Context);
        return base.SavingChangesAsync(eventData, result, cancellationToken);
    }

    private void UpdateAuditFields(DbContext? context)
    {
        if (context is null) return;

        var now = DateTime.UtcNow;
        var userId = auditContext.UserId;

        foreach (var entry in context.ChangeTracker.Entries<BaseEntity<long>>())
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    entry.Entity.CreatedAt = now;
                    entry.Entity.CreatedBy = userId;
                    break;

                case EntityState.Modified:
                    entry.Entity.UpdatedAt = now;
                    entry.Entity.UpdatedBy = userId;
                    break;
            }
        }
    }
}

// Registration
builder.Services.AddDbContext<AppDbContext>((sp, options) =>
{
    options.UseNpgsql(connectionString);
    options.AddInterceptors(sp.GetRequiredService<AuditInterceptor>());
});
```

---

## PostgreSQL Extensions

### pgvector (Vector Similarity Search)

```bash
dotnet add package Pgvector.EntityFrameworkCore
```

```csharp
// Entity
public class DocumentEntity
{
    public long Id { get; set; }
    public string Content { get; set; } = string.Empty;
    public Vector? Embedding { get; set; }  // 1536 dimensions for OpenAI
}

// Configuration
builder.HasPostgresExtension("vector");

builder.Entity<DocumentEntity>()
    .Property(d => d.Embedding)
    .HasColumnType("vector(1536)");

// Create HNSW index for fast similarity search
builder.Entity<DocumentEntity>()
    .HasIndex(d => d.Embedding)
    .HasMethod("hnsw")
    .HasOperators("vector_cosine_ops");

// Query by similarity
var queryEmbedding = await embeddingService.GenerateAsync(searchText);

var similar = await context.Documents
    .OrderBy(d => d.Embedding!.CosineDistance(queryEmbedding))
    .Take(10)
    .ToListAsync(ct);
```

### PostGIS (Geospatial)

```bash
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL.NetTopologySuite
```

```csharp
// Setup
options.UseNpgsql(connectionString, o => o.UseNetTopologySuite());

// Entity
public class LocationEntity
{
    public long Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public Point Coordinates { get; set; } = null!;  // NetTopologySuite
}

// Configuration
builder.HasPostgresExtension("postgis");

builder.Entity<LocationEntity>()
    .Property(l => l.Coordinates)
    .HasColumnType("geography(Point, 4326)");

// Query by distance
var searchPoint = new Point(-122.4194, 37.7749) { SRID = 4326 };
var radiusMeters = 5000;

var nearby = await context.Locations
    .Where(l => l.Coordinates.Distance(searchPoint) <= radiusMeters)
    .OrderBy(l => l.Coordinates.Distance(searchPoint))
    .ToListAsync(ct);
```

### Full-Text Search

```csharp
// Entity with search vector
public class ArticleEntity
{
    public long Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public NpgsqlTsVector SearchVector { get; set; } = null!;
}

// Configuration
builder.Entity<ArticleEntity>()
    .HasGeneratedTsVectorColumn(
        a => a.SearchVector,
        "english",
        a => new { a.Title, a.Content })
    .HasIndex(a => a.SearchVector)
    .HasMethod("GIN");

// Query
var results = await context.Articles
    .Where(a => a.SearchVector.Matches(EF.Functions.ToTsQuery("english", searchTerm)))
    .OrderByDescending(a => a.SearchVector.Rank(EF.Functions.ToTsQuery("english", searchTerm)))
    .ToListAsync(ct);
```

---

## Migrations

```bash
# Create migration
dotnet ef migrations add AddProductsTable \
    --project src/MyApp.Data \
    --startup-project src/MyApp.Api

# Apply migrations
dotnet ef database update \
    --project src/MyApp.Data \
    --startup-project src/MyApp.Api

# Generate SQL script
dotnet ef migrations script \
    --project src/MyApp.Data \
    --startup-project src/MyApp.Api \
    --idempotent \
    --output migrations.sql
```

### Migration Best Practices

```csharp
// ✅ Use idempotent migrations for production
migrationBuilder.Sql(@"
    CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_products_status
    ON products (status);
", suppressTransaction: true);  // CONCURRENTLY requires no transaction

// ✅ Add data migrations carefully
migrationBuilder.Sql(@"
    UPDATE products SET status = 'Active' WHERE status IS NULL;
");

// ✅ Handle nullable changes
migrationBuilder.AlterColumn<string>(
    name: "description",
    table: "products",
    nullable: true,  // Make nullable first
    oldNullable: false);
```

---

## Performance Tips

| Tip | Impact |
|-----|--------|
| Use `AsNoTracking()` for reads | Reduces memory, faster queries |
| Use `ProjectTo<T>()` | Only selects needed columns |
| Use `AsSplitQuery()` | Prevents cartesian explosion |
| Add appropriate indexes | Faster WHERE/ORDER BY |
| Use `ExecuteUpdateAsync` / `ExecuteDeleteAsync` | Bulk operations |
| Use connection pooling | Reuse connections |
| Use `IQueryable` not `IEnumerable` | Server-side filtering |
| Avoid `ToList()` before filtering | Client-side filtering is slow |
