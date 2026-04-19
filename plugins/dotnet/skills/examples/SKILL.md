---
name: dotnet:examples
description: Curated example repo finder — point the user at real .NET projects that demonstrate a pattern (Clean Architecture, eShop, Blazor demos, MAUI samples).
argument-hint: <topic>
effort: low
---

# examples

Map a topic to a canonical open-source reference implementation.

## Why

When planning a feature, a proven reference beats inventing from
scratch. This skill is the index.

## Curated Registry

### Full-stack Reference Apps

| Project | What | Link |
|---------|------|------|
| `dotnet/eShop` | Microservices, Aspire, Blazor, EF | github.com/dotnet/eShop |
| `ardalis/CleanArchitecture` | Clean Arch template | github.com/ardalis/CleanArchitecture |
| `jasontaylordev/CleanArchitecture` | Another Clean Arch take | github.com/jasontaylordev/CleanArchitecture |
| `dotnet-architecture/eShopOnWeb` | Web app, DDD | github.com/dotnet-architecture/eShopOnWeb |

### ASP.NET Core APIs

| Project | What |
|---------|------|
| `dotnet/aspire-samples` | Aspire orchestration, service discovery |
| `davidfowl/TodoApi` | Minimal API auth, JWT, OpenAPI |
| `dotnet/AspNetCore.Docs.Samples` | Official docs samples |

### EF Core

| Project | What |
|---------|------|
| `dotnet/efcore.samples` | Official EF Core samples |
| `ardalis/Specification` | Query specification pattern |

### Blazor

| Project | What |
|---------|------|
| `dotnet/blazor-samples` | Official Blazor samples |
| `BlazorHero/CleanArchitecture` | Blazor + Clean Arch |
| `radzenhq/radzen-blazor` | UI component library |

### MAUI

| Project | What |
|---------|------|
| `dotnet/maui-samples` | Official MAUI samples |
| `CommunityToolkit/Maui` | Toolkit patterns |

### WPF

| Project | What |
|---------|------|
| `dotnet/samples` (Windows) | Official WPF samples |
| `MaterialDesignInXAML` | Material Design + MVVM patterns |

### Testing

| Project | What |
|---------|------|
| `dotnet-testcontainers/testcontainers-dotnet` | Integration testing |
| `Moq/moq` | Moq docs/examples |
| `nsubstitute/NSubstitute` | NSubstitute samples |

### Performance

| Project | What |
|---------|------|
| `dotnet/BenchmarkDotNet` | Benchmarks + samples |
| `dotnet/performance` | Official perf tests & patterns |

## Flow

1. User describes the pattern they want to learn/implement
2. Match against the registry above
3. Return the **2–3 most relevant** repos with a one-line "why this
   one" for each
4. If nothing matches, say so — don't recommend random results
5. Suggest specific files/paths to read within the recommended repo
   when known (e.g., eShop's Catalog service for EF + MediatR pattern)

## Iron Laws

- Never recommend a repo without verifying it's maintained (check
  last commit date)
- Never recommend an archived/abandoned repo without flagging
- Don't recommend a repo that's outdated for the user's .NET version
  (net4.x sample for a net8.0 user)

## Output

Inline response only; no file written. Example:

```markdown
For "Blazor + Clean Architecture", two strong references:

1. **BlazorHero/CleanArchitecture** — Blazor WASM frontend, MediatR,
   Identity. Last active 2024. Read `src/Application/` for UseCase
   pattern.

2. **ardalis/CleanArchitecture + Blazor template** — simpler,
   maintained template. Use `dotnet new clean-arch -o MyApp`.

eShop is richer but microservice-first, which is overkill unless you
already need service split.
```

## References

- `${CLAUDE_SKILL_DIR}/references/registry.md` — full registry with
  maintenance status
- `${CLAUDE_SKILL_DIR}/references/eshop-tour.md` — guided tour of
  eShop's structure
- `${CLAUDE_SKILL_DIR}/references/aspire-samples.md` — Aspire sample
  deep-dives

## Anti-patterns

- Dumping the full registry in response — curate
- Recommending abandoned repos
- Not checking .NET version compatibility
- Too many recommendations (choice paralysis) — max 3
