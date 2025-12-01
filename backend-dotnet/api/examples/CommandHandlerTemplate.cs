// Example command handler demonstrating best practices
// Location: src/MyApp.Services/Handlers/Commands/CreateProductCommandHandler.cs

using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;
using MyApp.Contracts.Commands;
using MyApp.Contracts.Dtos;
using MyApp.Contracts.Events;
using MyApp.Contracts.Interfaces;
using MyApp.Data.Entities;

namespace MyApp.Services.Handlers.Commands;

/// <summary>
/// Handles the creation of a new product.
/// </summary>
public class CreateProductCommandHandler(
    IProductRepository repository,
    IMapper mapper,
    IEventPublisher eventPublisher,
    ILogger<CreateProductCommandHandler> logger
) : IRequestHandler<CreateProductCommand, ProductDto>
{
    public async Task<ProductDto> Handle(
        CreateProductCommand request,
        CancellationToken cancellationToken)
    {
        logger.LogInformation(
            "Creating product {ProductName} for user {UserId}",
            request.Dto.Name,
            request.UserId);

        // Map DTO to entity
        var entity = mapper.Map<ProductEntity>(request.Dto);

        // Set audit fields
        entity.CreatedBy = request.UserId;
        entity.CreatedAt = DateTime.UtcNow;
        entity.Status = ProductStatus.Draft;

        // Persist
        await repository.AddAsync(entity, cancellationToken);

        logger.LogInformation(
            "Product {ProductId} created successfully",
            entity.Id);

        // Publish domain event
        await eventPublisher.PublishAsync(
            new ProductCreatedEvent(entity.Id, entity.Name, request.UserId),
            cancellationToken);

        // Return mapped DTO
        return mapper.Map<ProductDto>(entity);
    }
}

// -------------------------------------------------------------------
// Command Definition (in MyApp.Contracts/Commands/CreateProductCommand.cs)
// -------------------------------------------------------------------

/// <summary>
/// Command to create a new product.
/// </summary>
/// <param name="Dto">Product creation data.</param>
/// <param name="UserId">ID of the user creating the product.</param>
public record CreateProductCommand(
    CreateProductDto Dto,
    Guid UserId
) : IRequest<ProductDto>, IValidatable;

// -------------------------------------------------------------------
// Update Command Handler Example
// -------------------------------------------------------------------

public class UpdateProductCommandHandler(
    IProductRepository repository,
    IMapper mapper,
    ILogger<UpdateProductCommandHandler> logger
) : IRequestHandler<UpdateProductCommand, ProductDto>
{
    public async Task<ProductDto> Handle(
        UpdateProductCommand request,
        CancellationToken cancellationToken)
    {
        logger.LogDebug(
            "Updating product {ProductId} for user {UserId}",
            request.Id,
            request.UserId);

        // Fetch existing entity (throws if not found)
        var entity = await repository.GetByIdForUpdateAsync(request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Product), request.Id);

        // Validate business rules
        if (entity.Status == ProductStatus.Archived)
        {
            throw new BusinessRuleException("Cannot update an archived product.");
        }

        // Map updates onto existing entity
        mapper.Map(request.Dto, entity);

        // Set audit fields
        entity.UpdatedBy = request.UserId;
        entity.UpdatedAt = DateTime.UtcNow;

        // Persist
        await repository.SaveChangesAsync(cancellationToken);

        logger.LogInformation(
            "Product {ProductId} updated successfully",
            entity.Id);

        return mapper.Map<ProductDto>(entity);
    }
}

public record UpdateProductCommand(
    long Id,
    UpdateProductDto Dto,
    Guid UserId
) : IRequest<ProductDto>, IValidatable;

// -------------------------------------------------------------------
// Delete Command Handler Example
// -------------------------------------------------------------------

public class DeleteProductCommandHandler(
    IProductRepository repository,
    ILogger<DeleteProductCommandHandler> logger
) : IRequestHandler<DeleteProductCommand>
{
    public async Task Handle(
        DeleteProductCommand request,
        CancellationToken cancellationToken)
    {
        logger.LogInformation(
            "Deleting product {ProductId} by user {UserId}",
            request.Id,
            request.UserId);

        var entity = await repository.GetByIdForUpdateAsync(request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Product), request.Id);

        // Validate business rules
        if (entity.Status == ProductStatus.Active)
        {
            throw new BusinessRuleException(
                "Cannot delete an active product. Archive it first.");
        }

        // Hard delete
        repository.Remove(entity);
        await repository.SaveChangesAsync(cancellationToken);

        logger.LogInformation(
            "Product {ProductId} deleted successfully",
            request.Id);
    }
}

public record DeleteProductCommand(
    long Id,
    Guid UserId
) : IRequest;

// -------------------------------------------------------------------
// Soft Delete Command Handler Example
// -------------------------------------------------------------------

public class SoftDeleteProductCommandHandler(
    IProductRepository repository,
    ILogger<SoftDeleteProductCommandHandler> logger
) : IRequestHandler<SoftDeleteProductCommand>
{
    public async Task Handle(
        SoftDeleteProductCommand request,
        CancellationToken cancellationToken)
    {
        logger.LogInformation(
            "Soft deleting product {ProductId} by user {UserId}",
            request.Id,
            request.UserId);

        var entity = await repository.GetByIdForUpdateAsync(request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Product), request.Id);

        // Soft delete
        entity.DeletedAt = DateTime.UtcNow;
        entity.DeletedBy = request.UserId;

        await repository.SaveChangesAsync(cancellationToken);

        logger.LogInformation(
            "Product {ProductId} soft deleted",
            request.Id);
    }
}

public record SoftDeleteProductCommand(
    long Id,
    Guid UserId
) : IRequest;
