---
name: observability
description: Observability patterns — ILogger<T>, structured logging, LoggerMessage source generators, OpenTelemetry traces/metrics/logs, Activity, HealthChecks, correlation IDs. Auto-loads for logging and telemetry code.
effort: medium
---

# observability

Observability patterns for .NET 8–11 — logs, metrics, traces.

## Iron Laws

- **#10**: `ILogger<T>` — never `Console.WriteLine` for application logs
- **#12**: `CancellationToken` flows through async operations (enables
  cancellation observability)
- Structured logging only — named placeholders, never interpolation

## Structured Logging

```csharp
// ✅ Structured — named placeholders extracted as fields
_logger.LogInformation("Order {OrderId} created for {CustomerId}",
    order.Id, order.CustomerId);

// ❌ Interpolation — log injection risk, no structured fields
_logger.LogInformation($"Order {order.Id} created for {order.CustomerId}");

// ❌ Console — bypasses sinks, filtering, scopes
Console.WriteLine($"Order created: {order.Id}");
```

## LoggerMessage Source Generators (.NET 6+)

High-performance, allocation-free logging:

```csharp
public static partial class OrderLogs
{
    [LoggerMessage(
        EventId = 1001,
        Level = LogLevel.Information,
        Message = "Order {OrderId} created for customer {CustomerId}")]
    public static partial void OrderCreated(
        this ILogger logger, long orderId, Guid customerId);

    [LoggerMessage(
        EventId = 1002,
        Level = LogLevel.Warning,
        Message = "Payment for order {OrderId} failed: {Reason}")]
    public static partial void PaymentFailed(
        this ILogger logger, long orderId, string reason);
}

// Usage
_logger.OrderCreated(order.Id, order.CustomerId);
```

Compile-time template validation; no boxing of value-type args.

## Scopes (request correlation)

```csharp
using (_logger.BeginScope(new Dictionary<string, object>
{
    ["CorrelationId"] = context.TraceIdentifier,
    ["UserId"] = user.Id
}))
{
    _logger.LogInformation("Processing order");
    // all logs inside scope inherit CorrelationId + UserId
}
```

## OpenTelemetry (traces + metrics + logs)

```csharp
builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r.AddService("MyApp", "1.0.0"))
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddSource("MyApp.*")
        .AddOtlpExporter())
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation()
        .AddMeter("MyApp.*")
        .AddOtlpExporter());

builder.Logging.AddOpenTelemetry(o =>
{
    o.IncludeFormattedMessage = true;
    o.IncludeScopes = true;
    o.AddOtlpExporter();
});
```

## Custom Activity (traces)

```csharp
public class OrderService(ILogger<OrderService> logger)
{
    private static readonly ActivitySource _source = new("MyApp.Orders");

    public async Task<Order> CreateAsync(CreateOrderRequest req, CancellationToken ct)
    {
        using var activity = _source.StartActivity("Order.Create");
        activity?.SetTag("customer.id", req.CustomerId);
        activity?.SetTag("item.count", req.Items.Count);

        try
        {
            var order = await ProcessAsync(req, ct);
            activity?.SetTag("order.id", order.Id);
            return order;
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            throw;
        }
    }
}
```

## Custom Metrics (System.Diagnostics.Metrics)

```csharp
public class OrderMetrics
{
    private readonly Counter<long> _created;
    private readonly Histogram<double> _duration;
    private readonly UpDownCounter<int> _inFlight;

    public OrderMetrics(IMeterFactory factory)
    {
        var meter = factory.Create("MyApp.Orders");
        _created = meter.CreateCounter<long>("orders.created", "{order}");
        _duration = meter.CreateHistogram<double>("orders.duration", "ms");
        _inFlight = meter.CreateUpDownCounter<int>("orders.in_flight", "{order}");
    }

    public void OrderCreated(string tier) =>
        _created.Add(1, new KeyValuePair<string, object?>("tier", tier));

    public IDisposable TrackInFlight()
    {
        _inFlight.Add(1);
        return new Defer(() => _inFlight.Add(-1));
    }
}

// Register
services.AddSingleton<OrderMetrics>();
```

## HealthChecks (already covered in deploy)

Health checks feed readiness/liveness probes — part of observability
surface.

## Application Insights (Azure)

```csharp
builder.Services.AddApplicationInsightsTelemetry();
// Or for OpenTelemetry exporter:
// .AddAzureMonitorTraceExporter(...)
```

## Serilog (alternative sink)

```csharp
builder.Host.UseSerilog((ctx, cfg) => cfg
    .ReadFrom.Configuration(ctx.Configuration)
    .Enrich.FromLogContext()
    .Enrich.WithMachineName()
    .WriteTo.Console(new JsonFormatter())
    .WriteTo.Seq("http://seq:5341"));
```

Use `ILogger<T>` via DI — same API, Serilog as backend. Don't call
`Log.Logger` directly.

## Correlation Across Async

`Activity.Current` flows automatically through `async`/`await` because
it uses `AsyncLocal<T>`. Same for logging scopes. No manual propagation
needed inside the process.

**Cross-service**: W3C Trace Context headers (`traceparent`) are
propagated automatically by `HttpClient` instrumentation when
OpenTelemetry is enabled.

## References

- `${CLAUDE_SKILL_DIR}/references/structured-logging.md` — LoggerMessage
  source gen, scopes, enrichment
- `${CLAUDE_SKILL_DIR}/references/opentelemetry.md` — tracing, metrics,
  logs pipeline, exporters
- `${CLAUDE_SKILL_DIR}/references/activity-patterns.md` — ActivitySource,
  sampling, tags, events
- `${CLAUDE_SKILL_DIR}/references/metrics.md` — Meter, Counter,
  Histogram, UpDownCounter, ObservableGauge
- `${CLAUDE_SKILL_DIR}/references/app-insights.md` — Azure Monitor
  integration + OTEL exporter
- `${CLAUDE_SKILL_DIR}/references/serilog.md` — configuration,
  enrichers, sinks, structured destructuring

## Anti-patterns

- `Console.WriteLine` for app logs (Iron Law #10)
- Interpolated log messages — log injection, lost structure
- Logging full exception via `ex.ToString()` as message (use `exception`
  param on `Log*` methods)
- Logging PII (passwords, tokens, full emails) — redact or omit
- `Activity.StartActivity` in hot path without sampling config — blows
  up trace volume
- No correlation ID → impossible to trace request across services
- `using static Serilog.Log; Log.Information(...)` — bypasses DI, loses
  scopes
