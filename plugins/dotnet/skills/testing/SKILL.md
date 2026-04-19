---
name: dotnet:testing
description: xUnit/NUnit/MSTest patterns, mocking (NSubstitute/Moq), WebApplicationFactory, EF test isolation, async tests. Auto-loads for *Tests.cs files.
effort: medium
---

# testing

.NET testing patterns focusing on xUnit (most common).

## Iron Laws

- No `.Result` / `.Wait()` in tests (Iron Law #2)
- `async Task` return, never `async void`
- Tests isolated — no shared mutable state across tests
- One behavior per test; descriptive `Method_Scenario_Expected` names

## xUnit Core

```csharp
public class OrderServiceTests
{
    [Fact]
    public async Task Create_ValidRequest_ReturnsCreatedOrder()
    {
        var sut = new OrderService(...);
        var result = await sut.CreateAsync(new(CustomerId: Guid.NewGuid(), Items: [...]));
        Assert.NotNull(result);
        Assert.Equal(CustomerId, result.CustomerId);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public async Task Create_InvalidQuantity_Throws(int qty)
    {
        var sut = new OrderService(...);
        await Assert.ThrowsAsync<ValidationException>(() =>
            sut.CreateAsync(new(CustomerId: Guid.NewGuid(), Items: [new(ProductId: Guid.NewGuid(), Quantity: qty)])));
    }
}
```

## Fixtures (shared setup)

```csharp
public class DatabaseFixture : IAsyncLifetime
{
    public PostgreSqlContainer Container { get; } = new PostgreSqlBuilder().Build();
    public AppDbContext Db { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        await Container.StartAsync();
        Db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(Container.GetConnectionString()).Options);
        await Db.Database.MigrateAsync();
    }

    public async Task DisposeAsync() { await Container.DisposeAsync(); await Db.DisposeAsync(); }
}

public class OrderRepoTests(DatabaseFixture fx) : IClassFixture<DatabaseFixture>
{
    [Fact]
    public async Task AddOrder_Persists() { /* use fx.Db */ }
}
```

## Mocking — NSubstitute (concise)

```csharp
var svc = Substitute.For<IOrderService>();
svc.GetAsync(42L, Arg.Any<CancellationToken>())
    .Returns(new OrderDto(42, Guid.NewGuid(), 100m, "Pending"));

var controller = new OrdersController(svc);
var result = await controller.Get(42, CancellationToken.None);

Assert.NotNull(result.Value);
await svc.Received(1).GetAsync(42L, Arg.Any<CancellationToken>());
```

### Moq

```csharp
var svc = new Mock<IOrderService>();
svc.Setup(x => x.GetAsync(42L, It.IsAny<CancellationToken>()))
   .ReturnsAsync(new OrderDto(42, Guid.NewGuid(), 100m, "Pending"));
// usage svc.Object
svc.Verify(x => x.GetAsync(42L, It.IsAny<CancellationToken>()), Times.Once);
```

**Don't mix NSubstitute + Moq in one project.** Pick one.

## WebApplicationFactory (Integration)

```csharp
public class Api_Orders_Tests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client = factory
        .WithWebHostBuilder(b => b.ConfigureTestServices(s =>
        {
            s.RemoveAll<DbContextOptions<AppDbContext>>();
            s.AddDbContext<AppDbContext>(o => o.UseInMemoryDatabase("test"));
        }))
        .CreateClient();

    [Fact]
    public async Task Get_Orders_Returns200()
    {
        var response = await _client.GetAsync("/api/v1/orders");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
```

Requires `public partial class Program;` at end of Program.cs.

## EF Test Isolation

```csharp
// Per-test unique in-memory DB
var options = new DbContextOptionsBuilder<AppDbContext>()
    .UseInMemoryDatabase(Guid.NewGuid().ToString())
    .Options;

// OR SQLite for relational semantics
var options = new DbContextOptionsBuilder<AppDbContext>()
    .UseSqlite("DataSource=:memory:")
    .Options;
var db = new AppDbContext(options);
db.Database.OpenConnection();
db.Database.EnsureCreated();

// OR Testcontainers for real DB (integration)
```

## Coverage — coverlet

```xml
<PackageReference Include="coverlet.collector" Version="*" />
```

```bash
dotnet test --collect:"XPlat Code Coverage"
```

## Logging in tests

```csharp
// Never mock ILogger<T>. Use NullLogger<T>.
var logger = NullLogger<OrderService>.Instance;
```

## References

- `${CLAUDE_SKILL_DIR}/references/xunit-patterns.md` — Fact/Theory,
  fixtures, IAsyncLifetime, parallel
- `${CLAUDE_SKILL_DIR}/references/moq-nsubstitute.md` — mocking
  comparison + patterns
- `${CLAUDE_SKILL_DIR}/references/integration-tests.md` — WebApplication
  Factory deep dive
- `${CLAUDE_SKILL_DIR}/references/webapplicationfactory.md` — auth, DB,
  time, random override
- `${CLAUDE_SKILL_DIR}/references/ef-tests.md` — InMemory vs SQLite vs
  Testcontainers trade-offs
- `${CLAUDE_SKILL_DIR}/references/builders.md` — test data builders
  pattern

## Anti-patterns

- Shared static mutable state in test class
- `DateTime.Now` / `Guid.NewGuid()` in SUT + test — use injectable
  `ITimeProvider`
- `Thread.Sleep(N)` for async timing — use deterministic signals
- `async void` test methods — exceptions disappear
- `_mock.Verify(...)` without any behavioral assertion
- Mocking `ILogger<T>` — use `NullLogger<T>.Instance`
- Mocking `HttpContext` / `DbContext` directly — use TestServer + in-memory
