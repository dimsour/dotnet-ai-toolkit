---
name: di-patterns
description: Dependency injection patterns — lifetimes, IOptions, keyed services, HttpClientFactory, factories, hosted services. Auto-loads for Program.cs and service registration code.
effort: medium
---

# di-patterns

DI patterns for `Microsoft.Extensions.DependencyInjection` (the built-in
MEDI container).

## Iron Laws

- **#31**: `DbContext` = `Scoped` (never Singleton/Transient)
- **#32**: HttpClient via `IHttpClientFactory`
- **#33**: `IOptions<T>` / `IOptionsSnapshot<T>` / `IOptionsMonitor<T>`
  over raw `IConfiguration` reads in hot paths

## Lifetime Quick Reference

| Lifetime | When | Examples |
|----------|------|----------|
| Singleton | App-lifetime, thread-safe, stateless | Caches, config, factories |
| Scoped | Per-request (ASP.NET) / per-operation | DbContext, UoW, per-user context |
| Transient | Every resolution, cheap | Validators, simple services |

## Captive Dependency (the classic bug)

```csharp
// BAD: Singleton captures Scoped
services.AddScoped<IUserContext, HttpUserContext>();
services.AddSingleton<IAuditor>(sp =>
    new Auditor(sp.GetRequiredService<IUserContext>()));
// Auditor keeps first scope's IUserContext forever.

// Fix 1: make Auditor Scoped too
services.AddScoped<IAuditor, Auditor>();

// Fix 2: inject factory, resolve per operation
services.AddSingleton<IAuditor>(sp =>
    new Auditor(sp.GetRequiredService<IServiceScopeFactory>()));
```

## DbContext — Always Scoped

```csharp
builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseSqlServer(builder.Configuration.GetConnectionString("Db")));

// Background service needs DbContext? Create a scope per iteration:
public class ReportWorker(IServiceScopeFactory scopeFactory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            await using var scope = scopeFactory.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            await ProcessAsync(db, ct);
            await Task.Delay(TimeSpan.FromMinutes(5), ct);
        }
    }
}
```

## HttpClient — Factory

```csharp
// Typed client
services.AddHttpClient<IStripeClient, StripeClient>((sp, c) =>
{
    var opts = sp.GetRequiredService<IOptions<StripeOptions>>().Value;
    c.BaseAddress = new(opts.BaseUrl);
    c.Timeout = TimeSpan.FromSeconds(30);
}).AddResilienceHandler("default", b => b
    .AddRetry(new() { MaxRetryAttempts = 3 })
    .AddTimeout(TimeSpan.FromSeconds(10)));

// Named client
services.AddHttpClient("github", c => c.BaseAddress = new("https://api.github.com"));
// Usage: IHttpClientFactory factory → factory.CreateClient("github")
```

## Options Pattern

```csharp
// Define
public class JwtOptions
{
    [Required] public string Issuer { get; init; } = "";
    [Required] public string Audience { get; init; } = "";
    [MinLength(32)] public string Key { get; init; } = "";
}

// Register with validation at startup
services.AddOptions<JwtOptions>()
    .Bind(builder.Configuration.GetSection("Jwt"))
    .ValidateDataAnnotations()
    .ValidateOnStart();

// Consume
public class TokenService(IOptions<JwtOptions> opts)
{
    private readonly JwtOptions _cfg = opts.Value;
    // ...
}

// Hot-reload (for feature flags)
public class FlagsService(IOptionsMonitor<FeatureFlags> monitor)
{
    public bool IsOn(string key) => monitor.CurrentValue[key];
}
```

## Keyed Services (.NET 8+)

```csharp
services.AddKeyedSingleton<IPayment, StripePayment>("stripe");
services.AddKeyedSingleton<IPayment, PayPalPayment>("paypal");

public class Checkout(
    [FromKeyedServices("stripe")] IPayment primary,
    [FromKeyedServices("paypal")] IPayment fallback) { }
```

## Factories

```csharp
// Delegate factory — pick impl by key
services.AddSingleton<Func<string, IPayment>>(sp => key => key switch
{
    "stripe" => sp.GetRequiredService<StripePayment>(),
    "paypal" => sp.GetRequiredService<PayPalPayment>(),
    _ => throw new ArgumentException(key)
});
```

## Multi-Registration

```csharp
services.AddScoped<IHandler, HandlerA>();
services.AddScoped<IHandler, HandlerB>();

public class Dispatcher(IEnumerable<IHandler> handlers)
{
    public async Task DispatchAsync(Event e) =>
        await Task.WhenAll(handlers.Select(h => h.HandleAsync(e)));
}
```

## References

- `${CLAUDE_SKILL_DIR}/references/lifetimes.md` — decision tree + captive
  dep examples
- `${CLAUDE_SKILL_DIR}/references/options.md` — validation, named options,
  reload
- `${CLAUDE_SKILL_DIR}/references/http-client.md` — typed/named,
  resilience, handler lifetime
- `${CLAUDE_SKILL_DIR}/references/keyed.md` — when keyed vs factory
- `${CLAUDE_SKILL_DIR}/references/hosted-services.md` — BackgroundService,
  scope factory pattern
- `${CLAUDE_SKILL_DIR}/references/disposal.md` — container disposal rules

## Anti-patterns

- `services.AddSingleton<DbContext>(...)` (Iron Law #31)
- `new HttpClient()` in constructor / hot path (Iron Law #32)
- Reading `_config["Section:Key"]` instead of IOptions (Iron Law #33)
- Injecting `IServiceProvider` (service locator)
- Captive dependencies — Singleton holding Scoped references
