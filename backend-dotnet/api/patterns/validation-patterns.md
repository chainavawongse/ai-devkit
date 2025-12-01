# Validation Patterns

Input validation using FluentValidation with MediatR pipeline integration.

## Setup

```bash
dotnet add package FluentValidation
dotnet add package FluentValidation.DependencyInjectionExtensions
```

```csharp
// Program.cs
services.AddValidatorsFromAssemblyContaining<CreateProductDtoValidator>();
```

---

## Basic Validator

```csharp
// Services/Validators/CreateProductDtoValidator.cs
public class CreateProductDtoValidator : AbstractValidator<CreateProductDto>
{
    public CreateProductDtoValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Product name is required")
            .MaximumLength(200).WithMessage("Product name cannot exceed 200 characters");

        RuleFor(x => x.Price)
            .GreaterThan(0).WithMessage("Price must be greater than zero")
            .LessThanOrEqualTo(1_000_000).WithMessage("Price cannot exceed 1,000,000");

        RuleFor(x => x.Sku)
            .NotEmpty().WithMessage("SKU is required")
            .Matches(@"^[A-Z]{3}-\d{4}$").WithMessage("SKU must match format XXX-0000");

        RuleFor(x => x.Description)
            .MaximumLength(2000).WithMessage("Description cannot exceed 2000 characters")
            .When(x => x.Description is not null);

        RuleFor(x => x.CategoryId)
            .GreaterThan(0).WithMessage("Valid category is required");
    }
}
```

---

## Common Validation Rules

### String Validation

```csharp
RuleFor(x => x.Name)
    .NotEmpty()                          // Not null/empty/whitespace
    .NotNull()                           // Not null (allows empty)
    .Length(1, 100)                      // Min/max length
    .MinimumLength(3)                    // Minimum length
    .MaximumLength(200)                  // Maximum length
    .Matches(@"^[a-zA-Z]+$")            // Regex pattern
    .EmailAddress()                      // Valid email format
    .Must(BeValidUrl);                   // Custom validation

private static bool BeValidUrl(string? url)
    => Uri.TryCreate(url, UriKind.Absolute, out _);
```

### Numeric Validation

```csharp
RuleFor(x => x.Price)
    .GreaterThan(0)
    .LessThan(1_000_000)
    .GreaterThanOrEqualTo(0.01m)
    .LessThanOrEqualTo(999_999.99m)
    .InclusiveBetween(1, 100)
    .ExclusiveBetween(0, 100)
    .PrecisionScale(10, 2, ignoreTrailingZeros: true);  // Decimal precision
```

### Collection Validation

```csharp
RuleFor(x => x.Tags)
    .NotEmpty().WithMessage("At least one tag is required")
    .Must(tags => tags.Count <= 10).WithMessage("Maximum 10 tags allowed");

RuleForEach(x => x.Tags)
    .NotEmpty()
    .MaximumLength(50);

RuleForEach(x => x.LineItems)
    .SetValidator(new OrderLineItemValidator());
```

### Date Validation

```csharp
RuleFor(x => x.StartDate)
    .NotEmpty()
    .GreaterThanOrEqualTo(DateTime.Today).WithMessage("Start date cannot be in the past");

RuleFor(x => x.EndDate)
    .GreaterThan(x => x.StartDate).WithMessage("End date must be after start date")
    .When(x => x.EndDate.HasValue);
```

### Enum Validation

```csharp
RuleFor(x => x.Status)
    .IsInEnum().WithMessage("Invalid status value");

RuleFor(x => x.Priority)
    .Must(BeValidPriority).WithMessage("Priority must be Low, Medium, or High");

private static bool BeValidPriority(string priority)
    => Enum.TryParse<Priority>(priority, ignoreCase: true, out _);
```

---

## Conditional Validation

```csharp
public class OrderValidator : AbstractValidator<CreateOrderDto>
{
    public OrderValidator()
    {
        // Validate only when condition is true
        RuleFor(x => x.ShippingAddress)
            .NotEmpty()
            .When(x => x.RequiresShipping);

        // Unless - opposite of When
        RuleFor(x => x.PickupLocation)
            .NotEmpty()
            .Unless(x => x.RequiresShipping);

        // Complex conditions
        RuleFor(x => x.GiftMessage)
            .MaximumLength(500)
            .When(x => x.IsGift && !string.IsNullOrEmpty(x.GiftMessage));

        // Dependent rules
        When(x => x.PaymentMethod == PaymentMethod.CreditCard, () =>
        {
            RuleFor(x => x.CardNumber).NotEmpty().CreditCard();
            RuleFor(x => x.CardExpiry).NotEmpty();
            RuleFor(x => x.CardCvv).NotEmpty().Length(3, 4);
        });

        When(x => x.PaymentMethod == PaymentMethod.BankTransfer, () =>
        {
            RuleFor(x => x.BankAccountNumber).NotEmpty();
            RuleFor(x => x.BankRoutingNumber).NotEmpty();
        });
    }
}
```

---

## Async Validation

For validations requiring database or external service calls:

```csharp
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

        RuleFor(x => x.Sku)
            .NotEmpty()
            .MustAsync(BeUniqueSku).WithMessage("SKU already exists");

        RuleFor(x => x.CategoryId)
            .MustAsync(BeValidCategory).WithMessage("Category does not exist");
    }

    private async Task<bool> BeUniqueSku(string sku, CancellationToken cancellationToken)
    {
        var exists = await _productRepository.ExistsBySkuAsync(sku, cancellationToken);
        return !exists;
    }

    private async Task<bool> BeValidCategory(long categoryId, CancellationToken cancellationToken)
    {
        return await _categoryRepository.ExistsAsync(categoryId, cancellationToken);
    }
}
```

---

## Cross-Property Validation

```csharp
public class DateRangeValidator : AbstractValidator<DateRangeDto>
{
    public DateRangeValidator()
    {
        RuleFor(x => x.EndDate)
            .GreaterThan(x => x.StartDate)
            .WithMessage("End date must be after start date");

        RuleFor(x => x)
            .Must(HaveValidDateRange)
            .WithMessage("Date range cannot exceed 1 year");
    }

    private static bool HaveValidDateRange(DateRangeDto dto)
    {
        return (dto.EndDate - dto.StartDate).TotalDays <= 365;
    }
}
```

---

## Child Validators

```csharp
// Child validator
public class AddressValidator : AbstractValidator<AddressDto>
{
    public AddressValidator()
    {
        RuleFor(x => x.Street).NotEmpty().MaximumLength(200);
        RuleFor(x => x.City).NotEmpty().MaximumLength(100);
        RuleFor(x => x.State).NotEmpty().Length(2);
        RuleFor(x => x.ZipCode).NotEmpty().Matches(@"^\d{5}(-\d{4})?$");
        RuleFor(x => x.Country).NotEmpty().Length(2);
    }
}

// Parent validator
public class CreateCustomerDtoValidator : AbstractValidator<CreateCustomerDto>
{
    public CreateCustomerDtoValidator()
    {
        RuleFor(x => x.Name).NotEmpty();

        // Use child validator
        RuleFor(x => x.BillingAddress)
            .SetValidator(new AddressValidator());

        RuleFor(x => x.ShippingAddress)
            .SetValidator(new AddressValidator())
            .When(x => x.ShippingAddress is not null);
    }
}
```

---

## MediatR Pipeline Integration

### Validation Behavior

```csharp
public class ValidationBehavior<TRequest, TResponse>(
    IEnumerable<IValidator<TRequest>> validators
) : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        if (!validators.Any())
            return await next();

        var context = new ValidationContext<TRequest>(request);

        var validationResults = await Task.WhenAll(
            validators.Select(v => v.ValidateAsync(context, cancellationToken)));

        var failures = validationResults
            .SelectMany(r => r.Errors)
            .Where(f => f is not null)
            .ToList();

        if (failures.Count > 0)
            throw new ValidationException(failures);

        return await next();
    }
}
```

### Command Validation

```csharp
// Validate the command's DTO, not the command itself
public class CreateProductCommandValidator : AbstractValidator<CreateProductCommand>
{
    public CreateProductCommandValidator(IValidator<CreateProductDto> dtoValidator)
    {
        RuleFor(x => x.Dto)
            .SetValidator(dtoValidator);

        RuleFor(x => x.UserId)
            .NotEmpty().WithMessage("User ID is required");
    }
}
```

---

## Custom Error Messages

```csharp
RuleFor(x => x.Email)
    .NotEmpty().WithMessage("Email is required")
    .EmailAddress().WithMessage("'{PropertyValue}' is not a valid email address")
    .MaximumLength(256).WithMessage("{PropertyName} cannot exceed {MaxLength} characters");

// Placeholders available:
// {PropertyName} - Name of property being validated
// {PropertyValue} - Current value
// {ComparisonValue} - Value being compared to
// {MinLength}, {MaxLength} - Length constraints
// {TotalLength} - Actual length of value
```

### Localized Messages

```csharp
RuleFor(x => x.Name)
    .NotEmpty()
    .WithMessage(x => string.Format(
        Resources.ValidationMessages.FieldRequired,
        nameof(x.Name)));
```

---

## Custom Validators

### Reusable Extension

```csharp
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
}

// Usage
RuleFor(x => x.Phone).PhoneNumber();
RuleFor(x => x.UrlSlug).Slug();
RuleFor(x => x.Attachment).MaxFileSize(10 * 1024 * 1024);
```

### Property Validator Class

```csharp
public class UniqueEmailValidator<T> : AsyncPropertyValidator<T, string>
{
    private readonly IUserRepository _userRepository;

    public UniqueEmailValidator(IUserRepository userRepository)
    {
        _userRepository = userRepository;
    }

    public override async Task<bool> IsValidAsync(
        ValidationContext<T> context,
        string value,
        CancellationToken cancellation)
    {
        if (string.IsNullOrEmpty(value))
            return true;

        var exists = await _userRepository.ExistsByEmailAsync(value, cancellation);
        return !exists;
    }

    public override string Name => "UniqueEmailValidator";

    protected override string GetDefaultMessageTemplate(string errorCode)
        => "Email '{PropertyValue}' is already registered.";
}
```

---

## Error Response Format

### Custom Exception

```csharp
// Shared/Exceptions/ValidationException.cs
public class ValidationException : Exception
{
    public IDictionary<string, string[]> Errors { get; }

    public ValidationException()
        : base("One or more validation failures have occurred.")
    {
        Errors = new Dictionary<string, string[]>();
    }

    public ValidationException(IEnumerable<ValidationFailure> failures)
        : this()
    {
        Errors = failures
            .GroupBy(e => e.PropertyName, e => e.ErrorMessage)
            .ToDictionary(g => g.Key, g => g.ToArray());
    }
}
```

### Exception Filter Handling

```csharp
// In ApiExceptionFilter
case ValidationException validationException:
    context.Result = new BadRequestObjectResult(new ValidationProblemDetails
    {
        Title = "Validation Failed",
        Status = StatusCodes.Status400BadRequest,
        Errors = validationException.Errors
    });
    break;
```

### Response Example

```json
{
  "title": "Validation Failed",
  "status": 400,
  "errors": {
    "Name": ["Product name is required"],
    "Price": ["Price must be greater than zero"],
    "Sku": ["SKU already exists"]
  }
}
```

---

## Best Practices

### Do

```csharp
// ✅ Validate DTOs, not entities
public class CreateProductDtoValidator : AbstractValidator<CreateProductDto>

// ✅ Use async validation for database checks
.MustAsync(BeUniqueSku)

// ✅ Provide clear error messages
.WithMessage("SKU must match format XXX-0000 (e.g., ABC-1234)")

// ✅ Use conditional validation
.When(x => x.RequiresShipping)

// ✅ Compose validators for nested objects
.SetValidator(new AddressValidator())

// ✅ Keep validators focused and testable
public class EmailValidator : AbstractValidator<string> { }
```

### Don't

```csharp
// ❌ Business logic in validators
RuleFor(x => x.OrderTotal)
    .Must(total => total >= CalculateMinimum(x.Items));  // Complex logic

// ❌ Side effects in validation
.Must(async (email, ct) => {
    await _emailService.SendVerification(email);  // Side effect!
    return true;
});

// ❌ Overly generic error messages
.WithMessage("Invalid");

// ❌ Validating everything as required when optional
RuleFor(x => x.MiddleName).NotEmpty();  // Should be optional
```
