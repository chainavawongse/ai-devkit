// Example query handler demonstrating best practices
// Location: src/MyApp.Services/Handlers/Queries/GetProductByIdQueryHandler.cs

using AutoMapper;
using MediatR;
using MyApp.Contracts.Dtos;
using MyApp.Contracts.Interfaces;
using MyApp.Contracts.Queries;
using MyApp.Shared.Exceptions;

namespace MyApp.Services.Handlers.Queries;

/// <summary>
/// Handles retrieval of a single product by ID.
/// </summary>
public class GetProductByIdQueryHandler(
    IProductRepository repository,
    IMapper mapper
) : IRequestHandler<GetProductByIdQuery, ProductDto>
{
    public async Task<ProductDto> Handle(
        GetProductByIdQuery request,
        CancellationToken cancellationToken)
    {
        var entity = await repository.GetByIdAsync(request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Product), request.Id);

        return mapper.Map<ProductDto>(entity);
    }
}

// Query Definition (in MyApp.Contracts/Queries/GetProductByIdQuery.cs)
public record GetProductByIdQuery(long Id) : IRequest<ProductDto>;

// -------------------------------------------------------------------
// List Query Handler with Filtering
// -------------------------------------------------------------------

public class GetProductsQueryHandler(
    IProductRepository repository,
    IMapper mapper
) : IRequestHandler<GetProductsQuery, IEnumerable<ProductDto>>
{
    public async Task<IEnumerable<ProductDto>> Handle(
        GetProductsQuery request,
        CancellationToken cancellationToken)
    {
        var query = repository.Query();

        // Apply filters
        if (request.Filter is not null)
        {
            if (!string.IsNullOrWhiteSpace(request.Filter.SearchTerm))
            {
                query = query.Where(p =>
                    p.Name.Contains(request.Filter.SearchTerm) ||
                    p.Description!.Contains(request.Filter.SearchTerm));
            }

            if (request.Filter.Status.HasValue)
            {
                query = query.Where(p => p.Status == request.Filter.Status.Value);
            }

            if (request.Filter.CategoryId.HasValue)
            {
                query = query.Where(p => p.CategoryId == request.Filter.CategoryId.Value);
            }

            if (request.Filter.MinPrice.HasValue)
            {
                query = query.Where(p => p.Price >= request.Filter.MinPrice.Value);
            }

            if (request.Filter.MaxPrice.HasValue)
            {
                query = query.Where(p => p.Price <= request.Filter.MaxPrice.Value);
            }
        }

        // Order and execute
        var entities = await query
            .OrderBy(p => p.Name)
            .ToListAsync(cancellationToken);

        return mapper.Map<IEnumerable<ProductDto>>(entities);
    }
}

public record GetProductsQuery(ProductFilter? Filter = null)
    : IRequest<IEnumerable<ProductDto>>;

// -------------------------------------------------------------------
// Paginated Query Handler
// -------------------------------------------------------------------

public class GetProductsPagedQueryHandler(
    IProductRepository repository,
    IMapper mapper
) : IRequestHandler<GetProductsPagedQuery, PaginatedResult<ProductDto>>
{
    public async Task<PaginatedResult<ProductDto>> Handle(
        GetProductsPagedQuery request,
        CancellationToken cancellationToken)
    {
        var query = repository.Query();

        // Apply filters
        if (!string.IsNullOrWhiteSpace(request.SearchTerm))
        {
            query = query.Where(p => p.Name.Contains(request.SearchTerm));
        }

        // Get total count
        var totalCount = await query.CountAsync(cancellationToken);

        // Apply pagination
        var entities = await query
            .OrderBy(p => p.Name)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync(cancellationToken);

        var items = mapper.Map<List<ProductDto>>(entities);

        return new PaginatedResult<ProductDto>
        {
            Items = items,
            TotalCount = totalCount,
            Page = request.Page,
            PageSize = request.PageSize
        };
    }
}

public record GetProductsPagedQuery(
    string? SearchTerm = null,
    int Page = 1,
    int PageSize = 20
) : IRequest<PaginatedResult<ProductDto>>;

// -------------------------------------------------------------------
// Query with Related Data
// -------------------------------------------------------------------

public class GetProductDetailQueryHandler(
    IProductRepository repository,
    IMapper mapper
) : IRequestHandler<GetProductDetailQuery, ProductDetailDto>
{
    public async Task<ProductDetailDto> Handle(
        GetProductDetailQuery request,
        CancellationToken cancellationToken)
    {
        var entity = await repository.Query()
            .Include(p => p.Category)
            .Include(p => p.Images)
            .Include(p => p.Reviews)
            .AsSplitQuery()
            .FirstOrDefaultAsync(p => p.Id == request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Product), request.Id);

        return mapper.Map<ProductDetailDto>(entity);
    }
}

public record GetProductDetailQuery(long Id) : IRequest<ProductDetailDto>;

// -------------------------------------------------------------------
// Projection Query (for performance)
// -------------------------------------------------------------------

public class GetProductSummariesQueryHandler(
    AppDbContext context
) : IRequestHandler<GetProductSummariesQuery, IEnumerable<ProductSummaryDto>>
{
    public async Task<IEnumerable<ProductSummaryDto>> Handle(
        GetProductSummariesQuery request,
        CancellationToken cancellationToken)
    {
        // Direct projection - only selects needed columns
        return await context.Products
            .AsNoTracking()
            .Where(p => p.Status == ProductStatus.Active)
            .Select(p => new ProductSummaryDto
            {
                Id = p.Id,
                Name = p.Name,
                Price = p.Price,
                ThumbnailUrl = p.Images
                    .OrderBy(i => i.SortOrder)
                    .Select(i => i.Url)
                    .FirstOrDefault()
            })
            .OrderBy(p => p.Name)
            .ToListAsync(cancellationToken);
    }
}

public record GetProductSummariesQuery : IRequest<IEnumerable<ProductSummaryDto>>;

// -------------------------------------------------------------------
// Supporting Types
// -------------------------------------------------------------------

public class ProductFilter
{
    public string? SearchTerm { get; init; }
    public ProductStatus? Status { get; init; }
    public long? CategoryId { get; init; }
    public decimal? MinPrice { get; init; }
    public decimal? MaxPrice { get; init; }
}

public class PaginatedResult<T>
{
    public IEnumerable<T> Items { get; init; } = [];
    public int TotalCount { get; init; }
    public int Page { get; init; }
    public int PageSize { get; init; }
    public int TotalPages => (int)Math.Ceiling(TotalCount / (double)PageSize);
    public bool HasNextPage => Page < TotalPages;
    public bool HasPreviousPage => Page > 1;
}

public record ProductSummaryDto
{
    public long Id { get; init; }
    public required string Name { get; init; }
    public decimal Price { get; init; }
    public string? ThumbnailUrl { get; init; }
}
