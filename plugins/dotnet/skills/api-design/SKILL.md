---
name: dotnet:api-design
description: ASP.NET Core API patterns — Minimal APIs vs Controllers, routing, DTOs, validation, middleware, versioning, ProblemDetails. Auto-loads for API work.
effort: medium
---

# api-design

ASP.NET Core Web API design reference.

## Iron Laws

- **#13**: `[Authorize]` on all non-public endpoints
- **#14**: DTOs at boundary — NEVER EF entities
- **#15**: Validation via `[ApiController]` or FluentValidation
- **#16**: Rate limit auth endpoints
- **#17**: CORS — never `AllowAnyOrigin()` in prod
- **#18**: `ProblemDetails` for errors — never raw exceptions

## Core Patterns

### Minimal API (preferred for new, small)

```csharp
var orders = app.MapGroup("/api/v1/orders")
    .RequireAuthorization()
    .WithTags("Orders");

orders.MapGet("/", async (IOrderService svc, CancellationToken ct) =>
    TypedResults.Ok(await svc.ListAsync(ct)))
    .Produces<List<OrderDto>>(200);

orders.MapPost("/", async (CreateOrderRequest req, IOrderService svc, CancellationToken ct) =>
{
    var dto = await svc.CreateAsync(req, ct);
    return TypedResults.Created($"/api/v1/orders/{dto.Id}", dto);
}).Produces<OrderDto>(201).ProducesValidationProblem();
```

### Controllers (when model binding / filters complex)

```csharp
[ApiController]
[Route("api/v1/[controller]")]
[Authorize]
public class OrdersController(IOrderService svc) : ControllerBase
{
    [HttpGet("{id:long}")]
    [ProducesResponseType(typeof(OrderDto), 200)]
    [ProducesResponseType(404)]
    public async Task<ActionResult<OrderDto>> Get(long id, CancellationToken ct)
    {
        var dto = await svc.GetAsync(id, ct);
        return dto is null ? NotFound() : Ok(dto);
    }
}
```

## DTOs

```csharp
public record OrderDto(long Id, Guid CustomerId, decimal Total, string Status);

public record CreateOrderRequest(
    [Required] Guid CustomerId,
    [MinLength(1)] IReadOnlyList<OrderItemRequest> Items);
```

## Middleware Order

```
UseExceptionHandler → UseHsts → UseHttpsRedirection → UseCors
→ UseAuthentication → UseAuthorization → UseRateLimiter → MapControllers
```

## Error Handling

```csharp
builder.Services.AddProblemDetails();
app.UseExceptionHandler();
app.UseStatusCodePages();

// Domain → HTTP
app.UseExceptionHandler(ex => ex.Run(async ctx =>
{
    var exc = ctx.Features.Get<IExceptionHandlerFeature>()?.Error;
    var status = exc switch
    {
        NotFoundException => 404,
        ValidationException => 400,
        ConflictException => 409,
        _ => 500
    };
    ctx.Response.StatusCode = status;
    await ctx.Response.WriteAsJsonAsync(new ProblemDetails
    {
        Status = status,
        Title = exc?.GetType().Name,
        Detail = status == 500 ? "An error occurred" : exc?.Message
    });
}));
```

## References

- `${CLAUDE_SKILL_DIR}/references/minimal-apis.md` — detailed Minimal API
  patterns
- `${CLAUDE_SKILL_DIR}/references/controllers.md` — controllers, filters,
  model binding
- `${CLAUDE_SKILL_DIR}/references/middleware.md` — pipeline design
- `${CLAUDE_SKILL_DIR}/references/validation.md` — FluentValidation vs
  DataAnnotations
- `${CLAUDE_SKILL_DIR}/references/versioning.md` — Asp.Versioning package
- `${CLAUDE_SKILL_DIR}/references/openapi.md` — .NET 9 AddOpenApi vs
  Swashbuckle
- `${CLAUDE_SKILL_DIR}/references/problemdetails.md` — RFC 7807
  implementation

## Anti-patterns

- Returning EF entities from endpoints
- Mixing Minimal + Controllers within one feature
- `IActionResult` when a typed `Results<TOk, TError>` is available
- Unversioned routes
- Sync-over-async in action methods
