---
name: perf
description: Performance analysis — EF query plans, async bottlenecks, GC pressure, BenchmarkDotNet setup, allocation profiling. Spawns performance-profiler agent.
argument-hint: "<file|endpoint|scenario>"
effort: high
---

# perf

Systematic performance investigation for .NET code.

## When to Use

- Endpoint latency regression
- Memory growth over time
- GC pause impact on latency
- "Feels slow" with no clear cause
- Pre-optimization measurement before refactor

Not for: micro-nits in cold paths. Measure before optimizing.

## Flow

1. **Clarify target**: which endpoint / workflow / query is slow? What
   latency/throughput are we observing?
2. **Spawn `performance-profiler` agent**
3. Profiler checks the top .NET perf smells:
   - **EF**: N+1, missing `AsNoTracking`, missing `.AsSplitQuery` for
     multi-include, cartesian explosion, client-side evaluation
   - **Async**: sync-over-async, missing `ConfigureAwait(false)` in
     libraries, `Task.Run` on the hot path to "avoid async"
   - **Allocations**: LINQ on hot path, `string.Format`/interpolation
     in logs, `ToList()` where `IEnumerable` suffices, boxing of
     value types
   - **HTTP**: missing `HttpCompletionOption.ResponseHeadersRead` for
     streaming, `HttpClient` per-request, missing response compression
   - **Concurrency**: `lock` on hot path, unnecessary `SemaphoreSlim`,
     `ConcurrentDictionary` misuse
   - **Startup**: missing AOT/ReadyToRun where applicable, too many
     `Assembly.Load` calls, large DI graph
4. **Suggest measurements** — BenchmarkDotNet micro-benchmark,
   `dotnet-counters`, `dotnet-trace`, `dotnet-gcdump`
5. **Produce report** with hypotheses ranked by expected impact

## BenchmarkDotNet Template

```csharp
[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net80)]
public class OrderQueryBenchmarks
{
    private AppDbContext _ctx = null!;

    [GlobalSetup] public void Setup() { /* ... */ }

    [Benchmark(Baseline = true)]
    public async Task<int> WithTracking() =>
        await _ctx.Orders.Where(o => o.Status == "Open").CountAsync();

    [Benchmark]
    public async Task<int> NoTracking() =>
        await _ctx.Orders.AsNoTracking().Where(o => o.Status == "Open").CountAsync();
}
```

## Iron Laws

- **#6**: `AsNoTracking()` on read queries
- **#11**: No N+1
- **#32**: `IHttpClientFactory` (socket exhaustion otherwise)
- **#2**: No `.Result` (deadlocks look like slow code)
- Don't optimize without measuring — hypotheses must be verified

## Output

`.claude/audit/perf-{scenario}.md`:

```markdown
# Perf Analysis: <scenario>

## Observed
- p99 latency: 1.8s
- Memory steady-state: 450 MB, growing to 900 MB under load

## Hypotheses (ranked by expected impact)

### 1. 🔴 N+1 query in /api/orders list
- File: src/Api/Orders/OrdersController.cs:47
- Current: foreach order { _ctx.Customer.Find(order.CustomerId) }
- Expected fix: .Include(o => o.Customer), or projected DTO
- Measurement: BenchmarkDotNet or logged EF queries

### 2. 🟠 Missing response compression
- ...

## Recommended Order
1. Fix N+1 (est -700ms p99)
2. Add compression (est -30% payload)
3. Profile with dotnet-counters if still slow
```

## References

- `${CLAUDE_SKILL_DIR}/references/bench-patterns.md` —
  BenchmarkDotNet setup, attributes, pitfalls
- `${CLAUDE_SKILL_DIR}/references/ef-query-analysis.md` — query plan
  inspection, Include vs projection, split queries
- `${CLAUDE_SKILL_DIR}/references/gc-pressure.md` — allocation-free
  patterns, `Span<T>`, `ArrayPool`, `ValueTask`
- `${CLAUDE_SKILL_DIR}/references/diagnostic-tools.md` —
  dotnet-counters, dotnet-trace, dotnet-gcdump, PerfView

## Anti-patterns

- Optimizing without measuring
- "`ToList()` is faster than `IEnumerable`" (it's not — it materializes)
- Adding `Task.Run` around awaited code "for perf"
- Micro-benchmarking with `Stopwatch` instead of BenchmarkDotNet
- Chasing allocations that are never in a hot path
