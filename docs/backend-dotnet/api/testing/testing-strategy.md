# Testing Strategy

Comprehensive testing approach using xUnit, Moq, and FluentAssertions.

## Setup

```bash
dotnet add package xunit
dotnet add package xunit.runner.visualstudio
dotnet add package Moq
dotnet add package FluentAssertions
dotnet add package Microsoft.EntityFrameworkCore.InMemory
dotnet add package Microsoft.AspNetCore.Mvc.Testing
```

---

## Testing Pyramid

```
        /\
       /  \
      / E2E \        10% - API tests
     /______\
    /        \
   / Integration \   20% - Repository + DB tests
  /______________\
 /                \
/   Unit Tests     \ 70% - Handlers, Services, Validators
\__________________/
```

---

## Project Structure

```
tests/
├── MyApp.Tests.Unit/
│   ├── Handlers/
│   │   ├── Commands/
│   │   │   ├── CreateProductCommandHandlerTests.cs
│   │   │   └── UpdateProductCommandHandlerTests.cs
│   │   └── Queries/
│   │       └── GetProductByIdQueryHandlerTests.cs
│   ├── Validators/
│   │   └── CreateProductDtoValidatorTests.cs
│   ├── Services/
│   │   └── ProductServiceTests.cs
│   └── GlobalUsings.cs
│
├── MyApp.Tests.Integration/
│   ├── Repositories/
│   │   └── ProductRepositoryTests.cs
│   ├── Fixtures/
│   │   └── DatabaseFixture.cs
│   └── GlobalUsings.cs
│
└── MyApp.Tests.Api/
    ├── Controllers/
    │   └── ProductsControllerTests.cs
    ├── Fixtures/
    │   └── WebApplicationFixture.cs
    └── GlobalUsings.cs
```

---

## Unit Testing Handlers

### Command Handler Test

```csharp
// Tests.Unit/Handlers/Commands/CreateProductCommandHandlerTests.cs
public class CreateProductCommandHandlerTests
{
    private readonly Mock<IProductRepository> _repositoryMock;
    private readonly Mock<IMapper> _mapperMock;
    private readonly Mock<IEventPublisher> _eventPublisherMock;
    private readonly CreateProductCommandHandler _handler;

    public CreateProductCommandHandlerTests()
    {
        _repositoryMock = new Mock<IProductRepository>();
        _mapperMock = new Mock<IMapper>();
        _eventPublisherMock = new Mock<IEventPublisher>();

        _handler = new CreateProductCommandHandler(
            _repositoryMock.Object,
            _mapperMock.Object,
            _eventPublisherMock.Object,
            Mock.Of<ILogger<CreateProductCommandHandler>>());
    }

    [Fact]
    public async Task Handle_ValidCommand_CreatesProductAndReturnsDto()
    {
        // Arrange
        var dto = new CreateProductDto { Name = "Widget", Price = 29.99m };
        var command = new CreateProductCommand(dto, Guid.NewGuid());

        var entity = new ProductEntity { Id = 1, Name = "Widget", Price = 29.99m };
        var resultDto = new ProductDto { Id = 1, Name = "Widget", Price = 29.99m };

        _mapperMock
            .Setup(m => m.Map<ProductEntity>(dto))
            .Returns(entity);

        _mapperMock
            .Setup(m => m.Map<ProductDto>(entity))
            .Returns(resultDto);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.Should().BeEquivalentTo(resultDto);

        _repositoryMock.Verify(
            r => r.AddAsync(entity, It.IsAny<CancellationToken>()),
            Times.Once);

        _eventPublisherMock.Verify(
            e => e.PublishAsync(
                It.Is<ProductCreatedEvent>(evt => evt.ProductId == entity.Id),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task Handle_RepositoryThrows_PropagatesException()
    {
        // Arrange
        var dto = new CreateProductDto { Name = "Widget", Price = 29.99m };
        var command = new CreateProductCommand(dto, Guid.NewGuid());

        _mapperMock
            .Setup(m => m.Map<ProductEntity>(It.IsAny<CreateProductDto>()))
            .Returns(new ProductEntity());

        _repositoryMock
            .Setup(r => r.AddAsync(It.IsAny<ProductEntity>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new DatabaseException("Connection failed", new Exception()));

        // Act
        var act = () => _handler.Handle(command, CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<DatabaseException>();
    }
}
```

### Query Handler Test

```csharp
public class GetProductByIdQueryHandlerTests
{
    private readonly Mock<IProductRepository> _repositoryMock;
    private readonly Mock<IMapper> _mapperMock;
    private readonly GetProductByIdQueryHandler _handler;

    public GetProductByIdQueryHandlerTests()
    {
        _repositoryMock = new Mock<IProductRepository>();
        _mapperMock = new Mock<IMapper>();

        _handler = new GetProductByIdQueryHandler(
            _repositoryMock.Object,
            _mapperMock.Object);
    }

    [Fact]
    public async Task Handle_ProductExists_ReturnsProductDto()
    {
        // Arrange
        var productId = 1L;
        var entity = new ProductEntity { Id = productId, Name = "Widget" };
        var dto = new ProductDto { Id = productId, Name = "Widget" };

        _repositoryMock
            .Setup(r => r.GetByIdAsync(productId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(entity);

        _mapperMock
            .Setup(m => m.Map<ProductDto>(entity))
            .Returns(dto);

        var query = new GetProductByIdQuery(productId);

        // Act
        var result = await _handler.Handle(query, CancellationToken.None);

        // Assert
        result.Should().BeEquivalentTo(dto);
    }

    [Fact]
    public async Task Handle_ProductNotFound_ThrowsEntityNotFoundException()
    {
        // Arrange
        var productId = 999L;

        _repositoryMock
            .Setup(r => r.GetByIdAsync(productId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((ProductEntity?)null);

        var query = new GetProductByIdQuery(productId);

        // Act
        var act = () => _handler.Handle(query, CancellationToken.None);

        // Assert
        await act.Should()
            .ThrowAsync<EntityNotFoundException>()
            .WithMessage($"*{productId}*");
    }
}
```

---

## Testing Validators

```csharp
public class CreateProductDtoValidatorTests
{
    private readonly CreateProductDtoValidator _validator;

    public CreateProductDtoValidatorTests()
    {
        _validator = new CreateProductDtoValidator();
    }

    [Fact]
    public async Task Validate_ValidDto_ReturnsNoErrors()
    {
        // Arrange
        var dto = new CreateProductDto
        {
            Name = "Widget",
            Price = 29.99m,
            Sku = "WDG-001"
        };

        // Act
        var result = await _validator.ValidateAsync(dto);

        // Assert
        result.IsValid.Should().BeTrue();
        result.Errors.Should().BeEmpty();
    }

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    [InlineData("   ")]
    public async Task Validate_EmptyName_ReturnsError(string? name)
    {
        // Arrange
        var dto = new CreateProductDto
        {
            Name = name!,
            Price = 29.99m,
            Sku = "WDG-001"
        };

        // Act
        var result = await _validator.ValidateAsync(dto);

        // Assert
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Name");
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(-100.50)]
    public async Task Validate_InvalidPrice_ReturnsError(decimal price)
    {
        // Arrange
        var dto = new CreateProductDto
        {
            Name = "Widget",
            Price = price,
            Sku = "WDG-001"
        };

        // Act
        var result = await _validator.ValidateAsync(dto);

        // Assert
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Price");
    }

    [Fact]
    public async Task Validate_NameTooLong_ReturnsError()
    {
        // Arrange
        var dto = new CreateProductDto
        {
            Name = new string('x', 201),  // Max is 200
            Price = 29.99m,
            Sku = "WDG-001"
        };

        // Act
        var result = await _validator.ValidateAsync(dto);

        // Assert
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e =>
            e.PropertyName == "Name" &&
            e.ErrorMessage.Contains("200"));
    }
}
```

---

## Integration Testing with Database

### Database Fixture

```csharp
// Tests.Integration/Fixtures/DatabaseFixture.cs
public class DatabaseFixture : IAsyncLifetime
{
    public AppDbContext Context { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql("Host=localhost;Database=myapp_test;Username=test;Password=test")
            .Options;

        Context = new AppDbContext(options);
        await Context.Database.EnsureCreatedAsync();
    }

    public async Task DisposeAsync()
    {
        await Context.Database.EnsureDeletedAsync();
        await Context.DisposeAsync();
    }
}

[CollectionDefinition("Database")]
public class DatabaseCollection : ICollectionFixture<DatabaseFixture> { }
```

### Repository Integration Test

```csharp
[Collection("Database")]
public class ProductRepositoryTests(DatabaseFixture fixture)
{
    private readonly AppDbContext _context = fixture.Context;
    private readonly ProductRepository _repository;

    public ProductRepositoryTests()
    {
        _repository = new ProductRepository(_context);
    }

    [Fact]
    public async Task AddAsync_ValidEntity_PersistsToDatabase()
    {
        // Arrange
        var product = new ProductEntity
        {
            Name = "Test Product",
            Price = 99.99m,
            Sku = $"TEST-{Guid.NewGuid():N}"[..12]
        };

        // Act
        await _repository.AddAsync(product);

        // Assert
        var retrieved = await _context.Products
            .FirstOrDefaultAsync(p => p.Id == product.Id);

        retrieved.Should().NotBeNull();
        retrieved!.Name.Should().Be(product.Name);
        retrieved.Price.Should().Be(product.Price);
    }

    [Fact]
    public async Task GetBySkuAsync_ExistingSku_ReturnsProduct()
    {
        // Arrange
        var sku = $"SKU-{Guid.NewGuid():N}"[..12];
        var product = new ProductEntity
        {
            Name = "Test Product",
            Price = 49.99m,
            Sku = sku
        };
        await _context.Products.AddAsync(product);
        await _context.SaveChangesAsync();

        // Act
        var result = await _repository.GetBySkuAsync(sku);

        // Assert
        result.Should().NotBeNull();
        result!.Sku.Should().Be(sku);
    }
}
```

### In-Memory Database Alternative

```csharp
public class ProductRepositoryInMemoryTests
{
    private readonly AppDbContext _context;
    private readonly ProductRepository _repository;

    public ProductRepositoryInMemoryTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new AppDbContext(options);
        _repository = new ProductRepository(_context);
    }

    [Fact]
    public async Task GetByIdAsync_NonExistent_ReturnsNull()
    {
        // Act
        var result = await _repository.GetByIdAsync(999);

        // Assert
        result.Should().BeNull();
    }
}
```

---

## API Integration Tests

### WebApplication Fixture

```csharp
// Tests.Api/Fixtures/WebApplicationFixture.cs
public class WebApplicationFixture : WebApplicationFactory<Program>, IAsyncLifetime
{
    public HttpClient Client { get; private set; } = null!;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureServices(services =>
        {
            // Replace real database with in-memory
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));

            if (descriptor != null)
                services.Remove(descriptor);

            services.AddDbContext<AppDbContext>(options =>
                options.UseInMemoryDatabase("TestDb"));

            // Replace external services with mocks
            services.AddScoped<IEmailService>(_ => Mock.Of<IEmailService>());
        });
    }

    public Task InitializeAsync()
    {
        Client = CreateClient();
        return Task.CompletedTask;
    }

    public new Task DisposeAsync()
    {
        Client.Dispose();
        return Task.CompletedTask;
    }
}

[CollectionDefinition("Api")]
public class ApiCollection : ICollectionFixture<WebApplicationFixture> { }
```

### Controller API Tests

```csharp
[Collection("Api")]
public class ProductsControllerTests(WebApplicationFixture fixture)
{
    private readonly HttpClient _client = fixture.Client;

    [Fact]
    public async Task Create_ValidProduct_ReturnsCreatedWithProduct()
    {
        // Arrange
        var dto = new CreateProductDto
        {
            Name = "Integration Test Product",
            Price = 49.99m,
            Sku = $"INT-{Guid.NewGuid():N}"[..12]
        };

        var content = new StringContent(
            JsonSerializer.Serialize(dto),
            Encoding.UTF8,
            "application/json");

        // Act
        var response = await _client.PostAsync("/api/products", content);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Created);

        var result = await response.Content.ReadFromJsonAsync<ProductDto>();
        result.Should().NotBeNull();
        result!.Name.Should().Be(dto.Name);
        result.Price.Should().Be(dto.Price);

        response.Headers.Location.Should().NotBeNull();
    }

    [Fact]
    public async Task Create_InvalidProduct_ReturnsBadRequest()
    {
        // Arrange
        var dto = new CreateProductDto
        {
            Name = "",  // Invalid
            Price = -10  // Invalid
        };

        var content = new StringContent(
            JsonSerializer.Serialize(dto),
            Encoding.UTF8,
            "application/json");

        // Act
        var response = await _client.PostAsync("/api/products", content);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var problem = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>();
        problem.Should().NotBeNull();
        problem!.Errors.Should().ContainKey("Name");
        problem.Errors.Should().ContainKey("Price");
    }

    [Fact]
    public async Task GetById_NonExistent_ReturnsNotFound()
    {
        // Act
        var response = await _client.GetAsync("/api/products/99999");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task GetById_Unauthorized_ReturnsUnauthorized()
    {
        // Arrange - no auth token

        // Act
        var response = await _client.GetAsync("/api/products/1");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }
}
```

### Authenticated API Tests

```csharp
public class AuthenticatedProductsControllerTests(WebApplicationFixture fixture)
{
    private readonly HttpClient _client;

    public AuthenticatedProductsControllerTests()
    {
        _client = fixture.CreateClient();

        // Add auth token
        var token = GenerateTestToken();
        _client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);
    }

    [Fact]
    public async Task GetById_Authenticated_ReturnsProduct()
    {
        // Act
        var response = await _client.GetAsync("/api/products/1");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    private static string GenerateTestToken()
    {
        // Generate a valid test JWT token
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes("test-secret-key-minimum-32-chars!"));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: "test-issuer",
            audience: "test-audience",
            claims:
            [
                new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()),
                new Claim(ClaimTypes.Role, "User")
            ],
            expires: DateTime.UtcNow.AddHours(1),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
```

---

## Test Patterns

### Arrange-Act-Assert

```csharp
[Fact]
public async Task MethodName_Scenario_ExpectedBehavior()
{
    // Arrange
    var input = CreateValidInput();
    var mock = SetupMock();

    // Act
    var result = await _sut.MethodAsync(input);

    // Assert
    result.Should().NotBeNull();
    mock.Verify(...);
}
```

### Theory with Data

```csharp
[Theory]
[InlineData("", false)]
[InlineData("valid@email.com", true)]
[InlineData("invalid", false)]
[InlineData("test@test.com", true)]
public async Task Validate_Email_ReturnsExpectedResult(string email, bool expectedValid)
{
    // Arrange
    var dto = new CreateUserDto { Email = email };

    // Act
    var result = await _validator.ValidateAsync(dto);

    // Assert
    result.IsValid.Should().Be(expectedValid);
}

// Or with MemberData for complex objects
public static IEnumerable<object[]> InvalidProducts =>
[
    [new CreateProductDto { Name = "", Price = 10 }, "Name"],
    [new CreateProductDto { Name = "Valid", Price = -1 }, "Price"],
    [new CreateProductDto { Name = "Valid", Price = 10, Sku = "" }, "Sku"]
];

[Theory]
[MemberData(nameof(InvalidProducts))]
public async Task Validate_InvalidProduct_HasExpectedError(
    CreateProductDto dto,
    string expectedErrorProperty)
{
    var result = await _validator.ValidateAsync(dto);

    result.IsValid.Should().BeFalse();
    result.Errors.Should().Contain(e => e.PropertyName == expectedErrorProperty);
}
```

---

## Global Usings

```csharp
// Tests.Unit/GlobalUsings.cs
global using Xunit;
global using Moq;
global using FluentAssertions;
global using MyApp.Contracts.Commands;
global using MyApp.Contracts.Queries;
global using MyApp.Contracts.Dtos;
global using MyApp.Data.Entities;
global using MyApp.Services.Handlers.Commands;
global using MyApp.Services.Handlers.Queries;
```

---

## Best Practices

### Do

```csharp
// ✅ One assertion concept per test
[Fact]
public async Task Create_ValidInput_ReturnsCreatedProduct()

// ✅ Clear test names: Method_Scenario_ExpectedBehavior
public async Task GetByIdAsync_ProductExists_ReturnsProduct()
public async Task GetByIdAsync_ProductNotFound_ThrowsException()

// ✅ Use FluentAssertions for readable assertions
result.Should().BeEquivalentTo(expected);
act.Should().ThrowAsync<EntityNotFoundException>();

// ✅ Use Theory for parameterized tests
[Theory]
[InlineData(0), InlineData(-1)]
public async Task Validate_InvalidPrice_ReturnsError(decimal price)

// ✅ Verify mock interactions
_mockRepo.Verify(r => r.AddAsync(It.IsAny<Entity>(), It.IsAny<CancellationToken>()), Times.Once);
```

### Don't

```csharp
// ❌ Multiple unrelated assertions
[Fact]
public async Task Test_Everything()
{
    result.Name.Should().Be("x");
    otherResult.Count.Should().Be(5);
    await service.ShouldNotThrowAsync();
}

// ❌ Vague test names
[Fact]
public async Task Test1()
public async Task ItWorks()

// ❌ Testing implementation details
_mockRepo.Verify(r => r.Query().Where(...).FirstOrDefault());  // Too specific

// ❌ Shared mutable state between tests
private static ProductEntity _sharedProduct;  // Can cause flaky tests
```
