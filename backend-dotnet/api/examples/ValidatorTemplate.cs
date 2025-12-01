// Example FluentValidation validators demonstrating best practices
// Location: src/MyApp.Services/Validators/CreateProductDtoValidator.cs

using FluentValidation;
using MyApp.Contracts.Dtos;
using MyApp.Contracts.Interfaces;

namespace MyApp.Services.Validators;

/// <summary>
/// Validator for product creation requests.
/// </summary>
public class CreateProductDtoValidator : AbstractValidator<CreateProductDto>
{
    private readonly IProductRepository _productRepository;
    private readonly ICategoryRepository _categoryRepository;

    public CreateProductDtoValidator(
        IProductRepository productRepository,
        ICategoryRepository categoryRepository)
    {
        _productRepository = productRepository;
        _categoryRepository = categoryRepository;

        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Product name is required")
            .MaximumLength(200).WithMessage("Product name cannot exceed 200 characters");

        RuleFor(x => x.Sku)
            .NotEmpty().WithMessage("SKU is required")
            .MaximumLength(50).WithMessage("SKU cannot exceed 50 characters")
            .Matches(@"^[A-Z0-9-]+$").WithMessage("SKU can only contain uppercase letters, numbers, and hyphens")
            .MustAsync(BeUniqueSku).WithMessage("A product with this SKU already exists");

        RuleFor(x => x.Price)
            .GreaterThan(0).WithMessage("Price must be greater than zero")
            .LessThanOrEqualTo(1_000_000).WithMessage("Price cannot exceed 1,000,000")
            .PrecisionScale(10, 2, ignoreTrailingZeros: true)
                .WithMessage("Price can have at most 2 decimal places");

        RuleFor(x => x.Description)
            .MaximumLength(2000).WithMessage("Description cannot exceed 2000 characters")
            .When(x => x.Description is not null);

        RuleFor(x => x.CategoryId)
            .GreaterThan(0).WithMessage("Category is required")
            .MustAsync(BeValidCategory).WithMessage("The specified category does not exist");

        RuleFor(x => x.Tags)
            .Must(tags => tags == null || tags.Count <= 10)
                .WithMessage("A product can have at most 10 tags");

        RuleForEach(x => x.Tags)
            .NotEmpty().WithMessage("Tag cannot be empty")
            .MaximumLength(50).WithMessage("Tag cannot exceed 50 characters")
            .When(x => x.Tags != null);
    }

    private async Task<bool> BeUniqueSku(string sku, CancellationToken cancellationToken)
    {
        return !await _productRepository.ExistsBySkuAsync(sku, cancellationToken);
    }

    private async Task<bool> BeValidCategory(long categoryId, CancellationToken cancellationToken)
    {
        return await _categoryRepository.ExistsAsync(categoryId, cancellationToken);
    }
}

// -------------------------------------------------------------------
// Update DTO Validator
// -------------------------------------------------------------------

public class UpdateProductDtoValidator : AbstractValidator<UpdateProductDto>
{
    private readonly IProductRepository _productRepository;

    public UpdateProductDtoValidator(IProductRepository productRepository)
    {
        _productRepository = productRepository;

        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Product name is required")
            .MaximumLength(200).WithMessage("Product name cannot exceed 200 characters");

        RuleFor(x => x.Price)
            .GreaterThan(0).WithMessage("Price must be greater than zero")
            .LessThanOrEqualTo(1_000_000).WithMessage("Price cannot exceed 1,000,000");

        RuleFor(x => x.Description)
            .MaximumLength(2000).WithMessage("Description cannot exceed 2000 characters")
            .When(x => x.Description is not null);
    }
}

// -------------------------------------------------------------------
// Conditional Validation Example
// -------------------------------------------------------------------

public class CreateOrderDtoValidator : AbstractValidator<CreateOrderDto>
{
    public CreateOrderDtoValidator()
    {
        RuleFor(x => x.CustomerId)
            .NotEmpty().WithMessage("Customer is required");

        RuleFor(x => x.LineItems)
            .NotEmpty().WithMessage("Order must have at least one line item");

        RuleForEach(x => x.LineItems)
            .SetValidator(new OrderLineItemDtoValidator());

        // Conditional: Shipping address required if not digital
        When(x => !x.IsDigitalOnly, () =>
        {
            RuleFor(x => x.ShippingAddress)
                .NotNull().WithMessage("Shipping address is required for physical orders")
                .SetValidator(new AddressDtoValidator()!);
        });

        // Conditional: Payment info based on method
        When(x => x.PaymentMethod == PaymentMethod.CreditCard, () =>
        {
            RuleFor(x => x.CardNumber)
                .NotEmpty().WithMessage("Card number is required")
                .CreditCard().WithMessage("Invalid credit card number");

            RuleFor(x => x.CardExpiry)
                .NotEmpty().WithMessage("Card expiry is required")
                .Must(BeValidExpiry).WithMessage("Card has expired");

            RuleFor(x => x.CardCvv)
                .NotEmpty().WithMessage("CVV is required")
                .Length(3, 4).WithMessage("CVV must be 3 or 4 digits");
        });

        When(x => x.PaymentMethod == PaymentMethod.BankTransfer, () =>
        {
            RuleFor(x => x.BankAccountNumber)
                .NotEmpty().WithMessage("Bank account number is required");

            RuleFor(x => x.BankRoutingNumber)
                .NotEmpty().WithMessage("Bank routing number is required");
        });
    }

    private static bool BeValidExpiry(string? expiry)
    {
        if (string.IsNullOrWhiteSpace(expiry)) return false;

        if (!DateTime.TryParseExact(expiry, "MM/yy", null, default, out var expiryDate))
            return false;

        return expiryDate > DateTime.UtcNow;
    }
}

// -------------------------------------------------------------------
// Child Validators
// -------------------------------------------------------------------

public class AddressDtoValidator : AbstractValidator<AddressDto>
{
    public AddressDtoValidator()
    {
        RuleFor(x => x.Street)
            .NotEmpty().WithMessage("Street is required")
            .MaximumLength(200).WithMessage("Street cannot exceed 200 characters");

        RuleFor(x => x.City)
            .NotEmpty().WithMessage("City is required")
            .MaximumLength(100).WithMessage("City cannot exceed 100 characters");

        RuleFor(x => x.State)
            .NotEmpty().WithMessage("State is required")
            .Length(2).WithMessage("State must be 2 characters");

        RuleFor(x => x.ZipCode)
            .NotEmpty().WithMessage("ZIP code is required")
            .Matches(@"^\d{5}(-\d{4})?$").WithMessage("Invalid ZIP code format");

        RuleFor(x => x.Country)
            .NotEmpty().WithMessage("Country is required")
            .Length(2).WithMessage("Country code must be 2 characters (ISO 3166-1 alpha-2)");
    }
}

public class OrderLineItemDtoValidator : AbstractValidator<OrderLineItemDto>
{
    public OrderLineItemDtoValidator()
    {
        RuleFor(x => x.ProductId)
            .GreaterThan(0).WithMessage("Product is required");

        RuleFor(x => x.Quantity)
            .GreaterThan(0).WithMessage("Quantity must be at least 1")
            .LessThanOrEqualTo(100).WithMessage("Quantity cannot exceed 100");

        RuleFor(x => x.UnitPrice)
            .GreaterThan(0).WithMessage("Unit price must be greater than zero");
    }
}

// -------------------------------------------------------------------
// Command Validator (validates the command, uses DTO validator)
// -------------------------------------------------------------------

public class CreateProductCommandValidator : AbstractValidator<CreateProductCommand>
{
    public CreateProductCommandValidator(
        IValidator<CreateProductDto> dtoValidator)
    {
        RuleFor(x => x.UserId)
            .NotEmpty().WithMessage("User ID is required");

        RuleFor(x => x.Dto)
            .NotNull().WithMessage("Product data is required")
            .SetValidator(dtoValidator);
    }
}

// -------------------------------------------------------------------
// Custom Validation Extensions
// -------------------------------------------------------------------

public static class CustomValidators
{
    public static IRuleBuilderOptions<T, string> PhoneNumber<T>(
        this IRuleBuilder<T, string> ruleBuilder)
    {
        return ruleBuilder
            .Matches(@"^\+?[1-9]\d{1,14}$")
            .WithMessage("'{PropertyValue}' is not a valid phone number");
    }

    public static IRuleBuilderOptions<T, string> Slug<T>(
        this IRuleBuilder<T, string> ruleBuilder)
    {
        return ruleBuilder
            .Matches(@"^[a-z0-9]+(?:-[a-z0-9]+)*$")
            .WithMessage("'{PropertyValue}' is not a valid URL slug");
    }

    public static IRuleBuilderOptions<T, IFormFile> MaxFileSize<T>(
        this IRuleBuilder<T, IFormFile> ruleBuilder,
        long maxSizeInBytes)
    {
        return ruleBuilder
            .Must(file => file == null || file.Length <= maxSizeInBytes)
            .WithMessage($"File size cannot exceed {maxSizeInBytes / 1024 / 1024}MB");
    }

    public static IRuleBuilderOptions<T, IFormFile> AllowedExtensions<T>(
        this IRuleBuilder<T, IFormFile> ruleBuilder,
        params string[] extensions)
    {
        return ruleBuilder
            .Must(file =>
            {
                if (file == null) return true;
                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                return extensions.Contains(ext);
            })
            .WithMessage($"Only {string.Join(", ", extensions)} files are allowed");
    }
}

// -------------------------------------------------------------------
// DTO Types (for reference)
// -------------------------------------------------------------------

public record CreateProductDto
{
    public required string Name { get; init; }
    public required string Sku { get; init; }
    public decimal Price { get; init; }
    public string? Description { get; init; }
    public long CategoryId { get; init; }
    public List<string>? Tags { get; init; }
}

public record UpdateProductDto
{
    public required string Name { get; init; }
    public decimal Price { get; init; }
    public string? Description { get; init; }
}

public record CreateOrderDto
{
    public Guid CustomerId { get; init; }
    public List<OrderLineItemDto> LineItems { get; init; } = [];
    public bool IsDigitalOnly { get; init; }
    public AddressDto? ShippingAddress { get; init; }
    public PaymentMethod PaymentMethod { get; init; }
    public string? CardNumber { get; init; }
    public string? CardExpiry { get; init; }
    public string? CardCvv { get; init; }
    public string? BankAccountNumber { get; init; }
    public string? BankRoutingNumber { get; init; }
}

public record OrderLineItemDto
{
    public long ProductId { get; init; }
    public int Quantity { get; init; }
    public decimal UnitPrice { get; init; }
}

public record AddressDto
{
    public required string Street { get; init; }
    public required string City { get; init; }
    public required string State { get; init; }
    public required string ZipCode { get; init; }
    public required string Country { get; init; }
}

public enum PaymentMethod
{
    CreditCard,
    BankTransfer,
    PayPal
}
