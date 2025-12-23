# Controller Patterns

RESTful API design, base controllers, and HTTP conventions.

## Controller Structure

Controllers should be thin - delegate business logic to MediatR handlers.

```csharp
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class ProductsController(IMediator mediator) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<ProductDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<ProductDto>>> GetAll(
        CancellationToken cancellationToken)
    {
        var query = new GetProductsQuery();
        var result = await mediator.Send(query, cancellationToken);
        return Ok(result);
    }

    [HttpGet("{id:long}")]
    [ProducesResponseType(typeof(ProductDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ProductDto>> GetById(
        long id,
        CancellationToken cancellationToken)
    {
        var query = new GetProductByIdQuery(id);
        var result = await mediator.Send(query, cancellationToken);
        return Ok(result);
    }

    [HttpPost]
    [ProducesResponseType(typeof(ProductDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ProductDto>> Create(
        CreateProductDto dto,
        CancellationToken cancellationToken)
    {
        var command = new CreateProductCommand(dto, UserId);
        var result = await mediator.Send(command, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpPut("{id:long}")]
    [ProducesResponseType(typeof(ProductDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ProductDto>> Update(
        long id,
        UpdateProductDto dto,
        CancellationToken cancellationToken)
    {
        var command = new UpdateProductCommand(id, dto, UserId);
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    [HttpPatch("{id:long}")]
    [ProducesResponseType(typeof(ProductDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ProductDto>> Patch(
        long id,
        PatchProductDto dto,
        CancellationToken cancellationToken)
    {
        var command = new PatchProductCommand(id, dto, UserId);
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    [HttpDelete("{id:long}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(
        long id,
        CancellationToken cancellationToken)
    {
        var command = new DeleteProductCommand(id, UserId);
        await mediator.Send(command, cancellationToken);
        return NoContent();
    }

    // Soft delete alternative
    [HttpPatch("{id:long}/delete")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> SoftDelete(
        long id,
        CancellationToken cancellationToken)
    {
        var command = new SoftDeleteProductCommand(id, UserId);
        await mediator.Send(command, cancellationToken);
        return NoContent();
    }
}
```

---

## Base Controller

Extract common functionality into a base controller:

```csharp
[ApiController]
[Authorize]
[ServiceFilter(typeof(ApiExceptionFilter))]
public abstract class ApiControllerBase : ControllerBase
{
    private IMediator? _mediator;

    protected IMediator Mediator =>
        _mediator ??= HttpContext.RequestServices.GetRequiredService<IMediator>();

    // Extract user claims
    protected Guid UserId =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? throw new UnauthorizedAccessException("User ID not found in claims"));

    protected string UserEmail =>
        User.FindFirstValue(ClaimTypes.Email)
            ?? throw new UnauthorizedAccessException("Email not found in claims");

    protected string? UserName =>
        User.FindFirstValue(ClaimTypes.Name);

    // For multi-tenant applications
    protected Guid CustomerId =>
        Guid.Parse(User.FindFirstValue("CustomerId")
            ?? throw new UnauthorizedAccessException("Customer ID not found in claims"));
}
```

Usage:

```csharp
[Route("api/[controller]")]
public class ProductsController : ApiControllerBase
{
    [HttpPost]
    public async Task<ActionResult<ProductDto>> Create(
        CreateProductDto dto,
        CancellationToken cancellationToken)
    {
        var command = new CreateProductCommand(dto, UserId, CustomerId);
        var result = await Mediator.Send(command, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }
}
```

---

## HTTP Methods & Status Codes

| Method | Action | Success | Common Errors |
|--------|--------|---------|---------------|
| GET | Retrieve resource(s) | 200 OK | 404 Not Found |
| POST | Create resource | 201 Created | 400 Bad Request, 409 Conflict |
| PUT | Full update | 200 OK | 400, 404 |
| PATCH | Partial update | 200 OK | 400, 404 |
| DELETE | Remove resource | 204 No Content | 404 |

### Response Patterns

```csharp
// 200 OK - Successful retrieval or update
return Ok(result);

// 201 Created - Resource created
return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
// Or with URI
return Created($"/api/products/{result.Id}", result);

// 204 No Content - Successful deletion or action with no response body
return NoContent();

// 400 Bad Request - Validation errors (handled by filter)
return BadRequest(new ProblemDetails { ... });

// 404 Not Found - Resource doesn't exist
return NotFound();

// 409 Conflict - Business rule violation
return Conflict(new ProblemDetails { Detail = "Product already exists" });
```

---

## Route Conventions

### Resource Naming

```csharp
// ✅ Plural nouns for collections
[Route("api/products")]
[Route("api/orders")]
[Route("api/customers")]

// ✅ Nested resources for relationships
[Route("api/customers/{customerId}/orders")]
[Route("api/orders/{orderId}/items")]
[Route("api/products/{productId}/reviews")]

// ❌ Avoid verbs in routes
[Route("api/get-products")]      // Bad
[Route("api/create-order")]      // Bad
```

### Route Constraints

```csharp
// Type constraints
[HttpGet("{id:int}")]
[HttpGet("{id:long}")]
[HttpGet("{id:guid}")]

// String constraints
[HttpGet("{slug:alpha}")]        // Letters only
[HttpGet("{code:length(6)}")]    // Exact length
[HttpGet("{sku:regex(^[A-Z]{{3}}-\\d{{4}}$)}")]  // Pattern

// Optional parameters
[HttpGet("{id:long?}")]

// Multiple constraints
[HttpGet("{id:long:min(1)}")]
```

---

## Custom Actions

For non-CRUD operations, use descriptive action routes:

```csharp
[Route("api/[controller]")]
public class OrdersController : ApiControllerBase
{
    // Standard CRUD
    [HttpGet("{id:long}")]
    public async Task<ActionResult<OrderDto>> GetById(long id, CancellationToken ct) { }

    // Custom actions - POST for state changes
    [HttpPost("{id:long}/submit")]
    public async Task<ActionResult<OrderDto>> Submit(long id, CancellationToken ct)
    {
        var command = new SubmitOrderCommand(id, UserId);
        var result = await Mediator.Send(command, ct);
        return Ok(result);
    }

    [HttpPost("{id:long}/cancel")]
    public async Task<ActionResult<OrderDto>> Cancel(
        long id,
        CancelOrderDto dto,
        CancellationToken ct)
    {
        var command = new CancelOrderCommand(id, dto.Reason, UserId);
        var result = await Mediator.Send(command, ct);
        return Ok(result);
    }

    [HttpPost("{id:long}/refund")]
    public async Task<ActionResult<RefundDto>> Refund(
        long id,
        RefundRequestDto dto,
        CancellationToken ct)
    {
        var command = new RefundOrderCommand(id, dto, UserId);
        var result = await Mediator.Send(command, ct);
        return Ok(result);
    }
}
```

---

## File Upload

```csharp
[HttpPost("{id:long}/attachments")]
[RequestSizeLimit(100_000_000)]  // 100MB
[DisableFormValueModelBinding]
public async Task<ActionResult<AttachmentDto>> UploadAttachment(
    long id,
    IFormFile file,
    CancellationToken cancellationToken)
{
    if (file.Length == 0)
        return BadRequest("File is empty");

    var command = new AttachFileCommand(id, file, UserId);
    var result = await Mediator.Send(command, cancellationToken);
    return Ok(result);
}

// Multiple files
[HttpPost("{id:long}/attachments/batch")]
public async Task<ActionResult<IEnumerable<AttachmentDto>>> UploadMultiple(
    long id,
    IFormFileCollection files,
    CancellationToken cancellationToken)
{
    var command = new AttachMultipleFilesCommand(id, files, UserId);
    var result = await Mediator.Send(command, cancellationToken);
    return Ok(result);
}
```

---

## File Download

```csharp
[HttpGet("{id:long}/attachments/{attachmentId:long}")]
public async Task<IActionResult> DownloadAttachment(
    long id,
    long attachmentId,
    CancellationToken cancellationToken)
{
    var query = new GetAttachmentQuery(id, attachmentId);
    var result = await Mediator.Send(query, cancellationToken);

    return File(
        result.Content,
        result.ContentType,
        result.FileName);
}

// Stream large files
[HttpGet("{id:long}/export")]
public async Task<IActionResult> ExportLargeFile(
    long id,
    CancellationToken cancellationToken)
{
    var query = new ExportProductDataQuery(id);
    var stream = await Mediator.Send(query, cancellationToken);

    return File(stream, "application/octet-stream", "export.csv");
}
```

---

## Request Cancellation

Always pass `CancellationToken` through the chain:

```csharp
[HttpGet]
public async Task<ActionResult<IEnumerable<ProductDto>>> GetAll(
    CancellationToken cancellationToken)  // Bound automatically from HttpContext
{
    var query = new GetProductsQuery();
    var result = await Mediator.Send(query, cancellationToken);
    return Ok(result);
}
```

This allows:
- Client-side request cancellation
- Server timeout enforcement
- Graceful shutdown handling

---

## Model Binding

### From Body (default for complex types)

```csharp
[HttpPost]
public async Task<IActionResult> Create([FromBody] CreateProductDto dto)
```

### From Route

```csharp
[HttpGet("{id:long}")]
public async Task<IActionResult> Get([FromRoute] long id)
```

### From Query String

```csharp
[HttpGet]
public async Task<IActionResult> Search(
    [FromQuery] string? name,
    [FromQuery] decimal? minPrice,
    [FromQuery] int page = 1,
    [FromQuery] int pageSize = 20)
```

### From Header

```csharp
[HttpGet]
public async Task<IActionResult> Get(
    [FromHeader(Name = "X-Correlation-Id")] string? correlationId)
```

### Combined

```csharp
[HttpPut("{id:long}")]
public async Task<IActionResult> Update(
    [FromRoute] long id,
    [FromBody] UpdateProductDto dto,
    [FromHeader(Name = "If-Match")] string? etag,
    CancellationToken cancellationToken)
```

---

## Swagger Documentation

```csharp
/// <summary>
/// Creates a new product.
/// </summary>
/// <param name="dto">The product creation data.</param>
/// <param name="cancellationToken">Cancellation token.</param>
/// <returns>The created product.</returns>
/// <response code="201">Returns the newly created product.</response>
/// <response code="400">If the request data is invalid.</response>
/// <response code="409">If a product with the same SKU already exists.</response>
[HttpPost]
[ProducesResponseType(typeof(ProductDto), StatusCodes.Status201Created)]
[ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
[ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
public async Task<ActionResult<ProductDto>> Create(
    CreateProductDto dto,
    CancellationToken cancellationToken)
{
    // Implementation
}
```

---

## Best Practices

### Do

```csharp
// ✅ Use CancellationToken
public async Task<IActionResult> Get(CancellationToken cancellationToken)

// ✅ Use ActionResult<T> for type-safe responses
public async Task<ActionResult<ProductDto>> Get()

// ✅ Return appropriate status codes
return CreatedAtAction(nameof(GetById), new { id }, result);

// ✅ Keep controllers thin - delegate to handlers
var result = await Mediator.Send(command, ct);

// ✅ Use route constraints
[HttpGet("{id:long:min(1)}")]

// ✅ Document with XML comments and ProducesResponseType
[ProducesResponseType(typeof(ProductDto), StatusCodes.Status200OK)]
```

### Don't

```csharp
// ❌ Business logic in controllers
[HttpPost]
public async Task<IActionResult> Create(CreateProductDto dto)
{
    var product = new Product { Name = dto.Name };  // Bad - mapping in controller
    await _context.Products.AddAsync(product);       // Bad - direct DB access
    await _context.SaveChangesAsync();
    return Ok(product);
}

// ❌ Catching exceptions in controllers
try {
    var result = await Mediator.Send(command);
    return Ok(result);
} catch (Exception ex) {
    return BadRequest(ex.Message);  // Bad - use exception filters
}

// ❌ Missing CancellationToken
public async Task<IActionResult> Get()  // Missing token

// ❌ Using IActionResult when type is known
public async Task<IActionResult> Get()  // Use ActionResult<T>
```
