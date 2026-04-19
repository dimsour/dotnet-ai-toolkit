#!/usr/bin/env bash
# SubagentStart hook: Inject .NET Iron Laws into all spawned subagents via additionalContext.
# Addresses zero skill auto-loading in subagents.

jq -n '{hookSpecificOutput: {hookEventName: "SubagentStart", additionalContext:
".NET Iron Laws (NON-NEGOTIABLE):
C# Core:
- NEVER float/double for money — use decimal
- NEVER .Result or .Wait() on Task — always await (sync-over-async deadlock)
- WRAP IDisposable in using / await using for IAsyncDisposable
- PROPAGATE CancellationToken through async I/O methods
- HONOR nullable annotations — dont !-away string? without proof
EF Core:
- USE AsNoTracking() for read-only queries
- PARAMETERIZE all SQL — never FromSqlRaw with $-interpolation
- ONE SaveChangesAsync per Unit of Work — never inside a loop
- .Include(...) BEFORE .Where(...) when eager-loading
- INDEX all foreign keys (verify in OnModelCreating)
- NO N+1 queries — use .Include / .ThenInclude / .AsSplitQuery
- HasPrecision(18,2) on decimal in OnModelCreating
ASP.NET Core:
- [Authorize] on ALL non-public endpoints (opt out with [AllowAnonymous])
- DTOs at API boundary — never expose EF entities
- Validate with [ApiController] ModelState or FluentValidation
- Rate limit auth endpoints
- Restrict CORS — never AllowAnyOrigin()
- Return ProblemDetails on errors via exception middleware
Blazor:
- StateHasChanged from non-UI thread needs InvokeAsync
- @key for dynamic lists
- NEVER store secrets in Blazor WASM — all code ships to browser
- Dispose subscriptions + timers in IDisposable.Dispose
MAUI/WPF:
- MVVM: no logic in code-behind
- ObservableCollection<T> for bindable lists
- Weak-event patterns for long-lived publishers
Security:
- NEVER interpolate SQL — parameters only
- HASH passwords via PasswordHasher<T> or Rfc2898DeriveBytes 100k+ iterations — never MD5/SHA1
- Secrets via User Secrets / Key Vault / env vars — NEVER appsettings.json
- JWT validation: issuer + audience + lifetime + signing key ALL required
- Anti-forgery tokens on state-changing form submissions
DI:
- DbContext = Scoped (never Singleton)
- HttpClient via IHttpClientFactory — never new HttpClient()
- Use IOptions<T> over raw IConfiguration in hot paths
Verification:
- VERIFY BEFORE CLAIMING DONE — run dotnet build && dotnet test; never say should work"}}'
