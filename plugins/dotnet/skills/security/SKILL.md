---
name: dotnet:security
description: Security patterns for .NET — authentication (JWT/cookie), authorization policies, secret management, CORS, anti-forgery, password hashing, OWASP mitigations. Auto-loads for auth/config code.
effort: high
---

# security

Security patterns for ASP.NET Core.

## Iron Laws

- **#13**: `[Authorize]` default, `[AllowAnonymous]` opt-out
- **#16**: Rate limit auth endpoints
- **#17**: CORS allowlist only — never `AllowAnyOrigin()`
- **#26**: Parameterized SQL only — no string interpolation
- **#27**: `PasswordHasher<T>` / Rfc2898DeriveBytes(100k+) — never
  MD5/SHA1
- **#28**: Secrets via User Secrets / Key Vault / env vars
- **#29**: JWT must validate issuer + audience + lifetime + signing key
- **#30**: Anti-forgery tokens on state-changing forms

## JWT Authentication

```csharp
var jwt = builder.Configuration.GetSection("Jwt").Get<JwtOptions>()!;

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.TokenValidationParameters = new()
        {
            ValidateIssuer = true,                // Iron Law #29
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ClockSkew = TimeSpan.FromSeconds(30)  // default 5min — tighten
        };
    });

builder.Services.AddAuthorization();
```

## Authorization Policies

```csharp
services.AddAuthorization(o =>
{
    o.AddPolicy("OwnsOrder", p => p.RequireAssertion(async ctx =>
    {
        var orderId = long.Parse(((DefaultHttpContext)ctx.Resource!).Request.RouteValues["id"]!.ToString()!);
        var userId = ctx.User.FindFirst("sub")?.Value;
        // DB check via scoped service via ctx.Resource services
        return await CheckOwnership(orderId, userId);
    }));
});

[Authorize(Policy = "OwnsOrder")]
[HttpGet("{id:long}")]
public Task<OrderDto> Get(long id, CancellationToken ct) => ...;
```

## Password Hashing

```csharp
// ASP.NET Core Identity
var hasher = new PasswordHasher<User>();
var hashed = hasher.HashPassword(user, plainText);
var verified = hasher.VerifyHashedPassword(user, user.PasswordHash, plainText);

// Or manually via Rfc2898DeriveBytes
using var pbkdf2 = new Rfc2898DeriveBytes(password, salt, iterations: 100_000, HashAlgorithmName.SHA256);
var hash = pbkdf2.GetBytes(32);
```

## Secrets

```bash
# User Secrets (dev only)
dotnet user-secrets init
dotnet user-secrets set "Stripe:ApiKey" "sk_test_..."
```

```csharp
// Prod
builder.Configuration.AddAzureKeyVault(new(vaultUri), new DefaultAzureCredential());
// or
builder.Configuration.AddEnvironmentVariables("MYAPP_");
// or Docker/K8s secret mount
builder.Configuration.AddKeyPerFile("/run/secrets", optional: true);
```

## CORS

```csharp
services.AddCors(o => o.AddPolicy("web", p => p
    .WithOrigins("https://app.example.com")
    .WithMethods("GET", "POST", "PUT", "DELETE")
    .WithHeaders("Content-Type", "Authorization")
    .AllowCredentials()));

app.UseCors("web");
```

**Never** `AllowAnyOrigin() + AllowCredentials()` (browser rejects, but the
pattern signals misunderstanding).

## Rate Limiting

```csharp
services.AddRateLimiter(o =>
{
    o.AddFixedWindowLimiter("auth", p =>
    {
        p.PermitLimit = 5;
        p.Window = TimeSpan.FromMinutes(1);
    });
});

app.MapPost("/login", LoginHandler).RequireRateLimiting("auth");
```

## Anti-Forgery

Razor Pages/MVC: automatic for POSTs via tag helpers.

API accepting cookie auth:

```csharp
services.AddAntiforgery(o => o.HeaderName = "X-CSRF-TOKEN");
app.Use(async (ctx, next) =>
{
    // send token on GET /api/csrf
    if (ctx.Request.Path == "/api/csrf")
    {
        var token = ctx.RequestServices.GetRequiredService<IAntiforgery>().GetAndStoreTokens(ctx);
        await ctx.Response.WriteAsJsonAsync(new { token = token.RequestToken });
        return;
    }
    await next();
});
```

## Exception Handling — no leakage

```csharp
services.AddProblemDetails();
app.UseExceptionHandler();
app.UseStatusCodePages();

// Never: app.UseDeveloperExceptionPage() in production
```

## Logging — no PII

```csharp
// ✅ Safe structured
_logger.LogInformation("Login attempt for user {UserId}", userId);

// ❌ Log injection
_logger.LogInformation($"Login attempt for user {username}");
```

## References

- `${CLAUDE_SKILL_DIR}/references/authentication.md` — JWT, cookies,
  OAuth flows, refresh
- `${CLAUDE_SKILL_DIR}/references/authorization.md` — policies, claims,
  resource-based
- `${CLAUDE_SKILL_DIR}/references/secrets.md` — User Secrets, Key Vault,
  env vars, K8s secrets
- `${CLAUDE_SKILL_DIR}/references/owasp-top10.md` — mitigations per OWASP
  category
- `${CLAUDE_SKILL_DIR}/references/data-protection.md` — ASP.NET Core
  Data Protection keys, cross-replica
- `${CLAUDE_SKILL_DIR}/references/csrf-cors.md` — CORS + XSRF
  interaction details

## Anti-patterns

- `JwtBearer` with missing validation flags (Iron Law #29)
- Plaintext secrets in committed config (Iron Law #28)
- MD5/SHA1 for passwords (Iron Law #27)
- `AllowAnyOrigin` in prod CORS (Iron Law #17)
- Custom crypto — use libraries
- Returning stack traces to clients
