// Example repository pattern demonstrating best practices
// Location: src/MyApp.Data/Repositories/Repository.cs

using Microsoft.EntityFrameworkCore;
using MyApp.Contracts.Interfaces;
using MyApp.Data.Entities;

namespace MyApp.Data.Repositories;

// -------------------------------------------------------------------
// Generic Repository Interface
// -------------------------------------------------------------------

/// <summary>
/// Generic repository interface for data access.
/// </summary>
public interface IRepository<TKey, TEntity> where TEntity : BaseEntity<TKey>
{
    /// <summary>
    /// Gets a queryable for read-only operations (no tracking).
    /// </summary>
    IQueryable<TEntity> Query();

    /// <summary>
    /// Gets a queryable for update operations (with tracking).
    /// </summary>
    IQueryable<TEntity> QueryForUpdate();

    /// <summary>
    /// Gets an entity by ID (no tracking).
    /// </summary>
    Task<TEntity?> GetByIdAsync(TKey id, CancellationToken ct = default);

    /// <summary>
    /// Gets an entity by ID for update (with tracking).
    /// </summary>
    Task<TEntity?> GetByIdForUpdateAsync(TKey id, CancellationToken ct = default);

    /// <summary>
    /// Adds a new entity.
    /// </summary>
    Task AddAsync(TEntity entity, CancellationToken ct = default);

    /// <summary>
    /// Adds multiple entities.
    /// </summary>
    Task AddRangeAsync(IEnumerable<TEntity> entities, CancellationToken ct = default);

    /// <summary>
    /// Marks an entity as modified.
    /// </summary>
    void Update(TEntity entity);

    /// <summary>
    /// Removes an entity.
    /// </summary>
    void Remove(TEntity entity);

    /// <summary>
    /// Checks if an entity exists.
    /// </summary>
    Task<bool> ExistsAsync(TKey id, CancellationToken ct = default);

    /// <summary>
    /// Saves all changes to the database.
    /// </summary>
    Task SaveChangesAsync(CancellationToken ct = default);
}

// -------------------------------------------------------------------
// Generic Repository Implementation
// -------------------------------------------------------------------

/// <summary>
/// Generic repository implementation using EF Core.
/// </summary>
public class Repository<TKey, TEntity>(AppDbContext context)
    : IRepository<TKey, TEntity>
    where TEntity : BaseEntity<TKey>
{
    protected readonly AppDbContext Context = context;
    protected readonly DbSet<TEntity> DbSet = context.Set<TEntity>();

    /// <inheritdoc />
    public IQueryable<TEntity> Query()
        => DbSet.AsNoTracking();

    /// <inheritdoc />
    public IQueryable<TEntity> QueryForUpdate()
        => DbSet.AsTracking();

    /// <inheritdoc />
    public async Task<TEntity?> GetByIdAsync(TKey id, CancellationToken ct = default)
        => await DbSet
            .AsNoTracking()
            .FirstOrDefaultAsync(e => e.Id!.Equals(id), ct);

    /// <inheritdoc />
    public async Task<TEntity?> GetByIdForUpdateAsync(TKey id, CancellationToken ct = default)
        => await DbSet.FirstOrDefaultAsync(e => e.Id!.Equals(id), ct);

    /// <inheritdoc />
    public async Task AddAsync(TEntity entity, CancellationToken ct = default)
    {
        await DbSet.AddAsync(entity, ct);
        await Context.SaveChangesAsync(ct);
    }

    /// <inheritdoc />
    public async Task AddRangeAsync(IEnumerable<TEntity> entities, CancellationToken ct = default)
    {
        await DbSet.AddRangeAsync(entities, ct);
        await Context.SaveChangesAsync(ct);
    }

    /// <inheritdoc />
    public void Update(TEntity entity)
    {
        DbSet.Update(entity);
    }

    /// <inheritdoc />
    public void Remove(TEntity entity)
    {
        DbSet.Remove(entity);
    }

    /// <inheritdoc />
    public async Task<bool> ExistsAsync(TKey id, CancellationToken ct = default)
        => await DbSet.AnyAsync(e => e.Id!.Equals(id), ct);

    /// <inheritdoc />
    public async Task SaveChangesAsync(CancellationToken ct = default)
        => await Context.SaveChangesAsync(ct);
}

// -------------------------------------------------------------------
// Specific Repository Interface
// -------------------------------------------------------------------

/// <summary>
/// Repository interface for Product entities.
/// </summary>
public interface IProductRepository : IRepository<long, ProductEntity>
{
    /// <summary>
    /// Gets a product by SKU.
    /// </summary>
    Task<ProductEntity?> GetBySkuAsync(string sku, CancellationToken ct = default);

    /// <summary>
    /// Checks if a product with the given SKU exists.
    /// </summary>
    Task<bool> ExistsBySkuAsync(string sku, CancellationToken ct = default);

    /// <summary>
    /// Gets products by category.
    /// </summary>
    Task<IEnumerable<ProductEntity>> GetByCategoryAsync(long categoryId, CancellationToken ct = default);

    /// <summary>
    /// Gets products by status.
    /// </summary>
    Task<IEnumerable<ProductEntity>> GetByStatusAsync(ProductStatus status, CancellationToken ct = default);

    /// <summary>
    /// Gets active products with low stock.
    /// </summary>
    Task<IEnumerable<ProductEntity>> GetLowStockAsync(int threshold, CancellationToken ct = default);

    /// <summary>
    /// Searches products by name or description.
    /// </summary>
    Task<IEnumerable<ProductEntity>> SearchAsync(string searchTerm, CancellationToken ct = default);

    /// <summary>
    /// Gets a product with all related data for detail view.
    /// </summary>
    Task<ProductEntity?> GetWithDetailsAsync(long id, CancellationToken ct = default);
}

// -------------------------------------------------------------------
// Specific Repository Implementation
// -------------------------------------------------------------------

/// <summary>
/// Repository implementation for Product entities.
/// </summary>
public class ProductRepository(AppDbContext context)
    : Repository<long, ProductEntity>(context), IProductRepository
{
    /// <inheritdoc />
    public async Task<ProductEntity?> GetBySkuAsync(string sku, CancellationToken ct = default)
    {
        return await Query()
            .FirstOrDefaultAsync(p => p.Sku == sku, ct);
    }

    /// <inheritdoc />
    public async Task<bool> ExistsBySkuAsync(string sku, CancellationToken ct = default)
    {
        return await Query()
            .AnyAsync(p => p.Sku == sku, ct);
    }

    /// <inheritdoc />
    public async Task<IEnumerable<ProductEntity>> GetByCategoryAsync(
        long categoryId,
        CancellationToken ct = default)
    {
        return await Query()
            .Where(p => p.CategoryId == categoryId)
            .OrderBy(p => p.Name)
            .ToListAsync(ct);
    }

    /// <inheritdoc />
    public async Task<IEnumerable<ProductEntity>> GetByStatusAsync(
        ProductStatus status,
        CancellationToken ct = default)
    {
        return await Query()
            .Where(p => p.Status == status)
            .OrderBy(p => p.Name)
            .ToListAsync(ct);
    }

    /// <inheritdoc />
    public async Task<IEnumerable<ProductEntity>> GetLowStockAsync(
        int threshold,
        CancellationToken ct = default)
    {
        return await Query()
            .Where(p => p.Status == ProductStatus.Active)
            .Where(p => p.StockQuantity <= threshold)
            .OrderBy(p => p.StockQuantity)
            .ToListAsync(ct);
    }

    /// <inheritdoc />
    public async Task<IEnumerable<ProductEntity>> SearchAsync(
        string searchTerm,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(searchTerm))
        {
            return [];
        }

        // PostgreSQL case-insensitive search
        return await Query()
            .Where(p => EF.Functions.ILike(p.Name, $"%{searchTerm}%") ||
                        EF.Functions.ILike(p.Description ?? "", $"%{searchTerm}%"))
            .OrderBy(p => p.Name)
            .Take(50)  // Limit search results
            .ToListAsync(ct);
    }

    /// <inheritdoc />
    public async Task<ProductEntity?> GetWithDetailsAsync(long id, CancellationToken ct = default)
    {
        return await Query()
            .Include(p => p.Category)
            .Include(p => p.Images.OrderBy(i => i.SortOrder))
            .Include(p => p.Tags)
            .AsSplitQuery()  // Prevent cartesian explosion
            .FirstOrDefaultAsync(p => p.Id == id, ct);
    }
}

// -------------------------------------------------------------------
// Persistence Service (Alternative Pattern)
// -------------------------------------------------------------------

/// <summary>
/// Higher-level persistence service that wraps repository operations.
/// Useful when you need additional logic or multiple repository coordination.
/// </summary>
public interface IProductPersistenceService
{
    Task<ProductEntity> CreateProductAsync(ProductEntity product, CancellationToken ct = default);
    Task<ProductEntity> UpdateProductAsync(ProductEntity product, CancellationToken ct = default);
    Task SoftDeleteProductAsync(long id, Guid userId, CancellationToken ct = default);
    Task HardDeleteProductAsync(long id, CancellationToken ct = default);
    Task RestoreProductAsync(long id, Guid userId, CancellationToken ct = default);
}

public class ProductPersistenceService(
    IProductRepository repository,
    ILogger<ProductPersistenceService> logger
) : IProductPersistenceService
{
    public async Task<ProductEntity> CreateProductAsync(
        ProductEntity product,
        CancellationToken ct = default)
    {
        await repository.AddAsync(product, ct);

        logger.LogInformation(
            "Product {ProductId} created with SKU {Sku}",
            product.Id,
            product.Sku);

        return product;
    }

    public async Task<ProductEntity> UpdateProductAsync(
        ProductEntity product,
        CancellationToken ct = default)
    {
        repository.Update(product);
        await repository.SaveChangesAsync(ct);

        logger.LogInformation(
            "Product {ProductId} updated",
            product.Id);

        return product;
    }

    public async Task SoftDeleteProductAsync(
        long id,
        Guid userId,
        CancellationToken ct = default)
    {
        var product = await repository.GetByIdForUpdateAsync(id, ct)
            ?? throw new EntityNotFoundException(nameof(Product), id);

        product.DeletedAt = DateTime.UtcNow;
        product.DeletedBy = userId;

        await repository.SaveChangesAsync(ct);

        logger.LogInformation(
            "Product {ProductId} soft deleted by user {UserId}",
            id,
            userId);
    }

    public async Task HardDeleteProductAsync(long id, CancellationToken ct = default)
    {
        var product = await repository.GetByIdForUpdateAsync(id, ct)
            ?? throw new EntityNotFoundException(nameof(Product), id);

        repository.Remove(product);
        await repository.SaveChangesAsync(ct);

        logger.LogWarning(
            "Product {ProductId} permanently deleted",
            id);
    }

    public async Task RestoreProductAsync(
        long id,
        Guid userId,
        CancellationToken ct = default)
    {
        // Query including soft-deleted
        var product = await repository.QueryForUpdate()
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new EntityNotFoundException(nameof(Product), id);

        if (!product.IsDeleted)
        {
            throw new BusinessRuleException("Product is not deleted");
        }

        product.DeletedAt = null;
        product.DeletedBy = null;
        product.UpdatedAt = DateTime.UtcNow;
        product.UpdatedBy = userId;

        await repository.SaveChangesAsync(ct);

        logger.LogInformation(
            "Product {ProductId} restored by user {UserId}",
            id,
            userId);
    }
}
