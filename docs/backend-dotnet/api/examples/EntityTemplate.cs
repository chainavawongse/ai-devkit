// Example EF Core entity and configuration demonstrating best practices
// Location: src/MyApp.Data/Entities/ProductEntity.cs

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MyApp.Data.Entities;

// -------------------------------------------------------------------
// Base Entity
// -------------------------------------------------------------------

/// <summary>
/// Base entity with common audit fields.
/// </summary>
public abstract class BaseEntity<TKey>
{
    public TKey Id { get; set; } = default!;
    public DateTime CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
}

/// <summary>
/// Base entity with soft delete support.
/// </summary>
public abstract class SoftDeletableEntity<TKey> : BaseEntity<TKey>
{
    public DateTime? DeletedAt { get; set; }
    public Guid? DeletedBy { get; set; }

    public bool IsDeleted => DeletedAt.HasValue;
}

// -------------------------------------------------------------------
// Product Entity
// -------------------------------------------------------------------

/// <summary>
/// Represents a product in the catalog.
/// </summary>
public class ProductEntity : SoftDeletableEntity<long>
{
    public required string Name { get; set; }
    public required string Sku { get; set; }
    public decimal Price { get; set; }
    public string? Description { get; set; }
    public ProductStatus Status { get; set; }
    public int StockQuantity { get; set; }

    // Foreign keys
    public long CategoryId { get; set; }

    // Navigation properties
    public CategoryEntity Category { get; set; } = null!;
    public ICollection<ProductImageEntity> Images { get; set; } = [];
    public ICollection<ProductTagEntity> Tags { get; set; } = [];
    public ICollection<OrderLineItemEntity> OrderLineItems { get; set; } = [];
}

public enum ProductStatus
{
    Draft,
    Active,
    Discontinued,
    Archived
}

// -------------------------------------------------------------------
// Entity Configuration
// -------------------------------------------------------------------

/// <summary>
/// EF Core configuration for ProductEntity.
/// </summary>
public class ProductEntityConfiguration : IEntityTypeConfiguration<ProductEntity>
{
    public void Configure(EntityTypeBuilder<ProductEntity> builder)
    {
        // Table name (PostgreSQL convention: lowercase with underscores)
        builder.ToTable("products");

        // Primary key
        builder.HasKey(p => p.Id);

        builder.Property(p => p.Id)
            .UseIdentityAlwaysColumn();  // PostgreSQL identity

        // Properties
        builder.Property(p => p.Name)
            .IsRequired()
            .HasMaxLength(200)
            .HasColumnName("name");

        builder.Property(p => p.Sku)
            .IsRequired()
            .HasMaxLength(50)
            .HasColumnName("sku");

        builder.Property(p => p.Price)
            .HasPrecision(18, 2)
            .HasColumnName("price");

        builder.Property(p => p.Description)
            .HasMaxLength(2000)
            .HasColumnName("description");

        builder.Property(p => p.Status)
            .HasConversion<string>()  // Store enum as string
            .HasMaxLength(50)
            .HasColumnName("status");

        builder.Property(p => p.StockQuantity)
            .HasColumnName("stock_quantity");

        builder.Property(p => p.CategoryId)
            .HasColumnName("category_id");

        // Audit columns
        builder.Property(p => p.CreatedAt)
            .HasColumnName("created_at");

        builder.Property(p => p.CreatedBy)
            .HasColumnName("created_by");

        builder.Property(p => p.UpdatedAt)
            .HasColumnName("updated_at");

        builder.Property(p => p.UpdatedBy)
            .HasColumnName("updated_by");

        builder.Property(p => p.DeletedAt)
            .HasColumnName("deleted_at");

        builder.Property(p => p.DeletedBy)
            .HasColumnName("deleted_by");

        // Indexes
        builder.HasIndex(p => p.Sku)
            .IsUnique()
            .HasDatabaseName("ix_products_sku");

        builder.HasIndex(p => p.Status)
            .HasDatabaseName("ix_products_status");

        builder.HasIndex(p => p.CategoryId)
            .HasDatabaseName("ix_products_category_id");

        builder.HasIndex(p => new { p.Status, p.CategoryId })
            .HasDatabaseName("ix_products_status_category");

        builder.HasIndex(p => p.CreatedAt)
            .HasDatabaseName("ix_products_created_at");

        // Global query filter (soft delete)
        builder.HasQueryFilter(p => p.DeletedAt == null);

        // Relationships
        builder.HasOne(p => p.Category)
            .WithMany(c => c.Products)
            .HasForeignKey(p => p.CategoryId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(p => p.Images)
            .WithOne(i => i.Product)
            .HasForeignKey(i => i.ProductId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(p => p.Tags)
            .WithOne(t => t.Product)
            .HasForeignKey(t => t.ProductId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

// -------------------------------------------------------------------
// Related Entities
// -------------------------------------------------------------------

public class CategoryEntity : BaseEntity<long>
{
    public required string Name { get; set; }
    public string? Description { get; set; }
    public long? ParentCategoryId { get; set; }

    // Navigation
    public CategoryEntity? ParentCategory { get; set; }
    public ICollection<CategoryEntity> SubCategories { get; set; } = [];
    public ICollection<ProductEntity> Products { get; set; } = [];
}

public class CategoryEntityConfiguration : IEntityTypeConfiguration<CategoryEntity>
{
    public void Configure(EntityTypeBuilder<CategoryEntity> builder)
    {
        builder.ToTable("categories");

        builder.HasKey(c => c.Id);

        builder.Property(c => c.Name)
            .IsRequired()
            .HasMaxLength(100)
            .HasColumnName("name");

        builder.Property(c => c.Description)
            .HasMaxLength(500)
            .HasColumnName("description");

        builder.Property(c => c.ParentCategoryId)
            .HasColumnName("parent_category_id");

        // Self-referencing relationship
        builder.HasOne(c => c.ParentCategory)
            .WithMany(c => c.SubCategories)
            .HasForeignKey(c => c.ParentCategoryId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class ProductImageEntity : BaseEntity<long>
{
    public long ProductId { get; set; }
    public required string Url { get; set; }
    public string? AltText { get; set; }
    public int SortOrder { get; set; }
    public bool IsPrimary { get; set; }

    public ProductEntity Product { get; set; } = null!;
}

public class ProductTagEntity
{
    public long ProductId { get; set; }
    public required string Tag { get; set; }

    public ProductEntity Product { get; set; } = null!;
}

public class OrderLineItemEntity : BaseEntity<long>
{
    public long OrderId { get; set; }
    public long ProductId { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal TotalPrice => Quantity * UnitPrice;

    public OrderEntity Order { get; set; } = null!;
    public ProductEntity Product { get; set; } = null!;
}

// -------------------------------------------------------------------
// DbContext
// -------------------------------------------------------------------

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<ProductEntity> Products => Set<ProductEntity>();
    public DbSet<CategoryEntity> Categories => Set<CategoryEntity>();
    public DbSet<ProductImageEntity> ProductImages => Set<ProductImageEntity>();
    public DbSet<OrderEntity> Orders => Set<OrderEntity>();
    public DbSet<OrderLineItemEntity> OrderLineItems => Set<OrderLineItemEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Apply all configurations from this assembly
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
