---
name: dotnet:boundaries
description: Analyze project/namespace boundaries, detect circular refs and layering violations via dotnet-depends and solution graph. Use before major refactors or to validate Clean Architecture.
argument-hint: <optional: project name or path>
effort: medium
---

# boundaries

Inspect and validate module boundaries in a .NET solution —
project references, namespace layering, and dependency direction.

## What to Check

1. **Project references** in `.csproj` — who depends on what
2. **Namespace traffic** — `using` statements crossing layer
   boundaries (UI → Infrastructure, Domain → Infrastructure, etc.)
3. **Circular references** — EF/DI containers mask these
4. **Public API surface** — `internal` vs `public` leakage across
   assembly lines
5. **`InternalsVisibleTo`** — should be test-only, rarely prod

## Flow

1. **Parse** all `.csproj` files for `<ProjectReference>` + package
   refs
2. **Build dependency DAG**; flag cycles
3. **Grep** `using` in each project; check against layering rules:
   - Domain/Core → must NOT reference Infrastructure, UI, Web
   - Application → MAY reference Domain; MUST NOT reference UI, Web
   - Infrastructure → MAY reference Domain, Application
   - Web/UI → MAY reference Application + Domain; MUST NOT reference
     Infrastructure internals directly (use Application interfaces)
4. **Report** boundary violations with file:line + offending `using`
5. **Suggest** refactor direction (interface extraction, DI
   inversion, moved types)

## Iron Laws

- Don't fix a boundary violation by making an internal type public
  (that's spreading, not fixing)
- Don't introduce a new project just to satisfy the analyzer — ensure
  cohesion is real
- Preserve Iron Laws — refactor must not break async, disposal, or
  auth guarantees

## Tools

```bash
# Dependency listing
dotnet list reference
dotnet list package --format json

# Solution graph (if installed)
dotnet-depends -p src/MyApp.sln

# Namespace scan
rg "^using [A-Z][^;]*;" --type cs -o | sort | uniq -c | sort -rn
```

## Layering Rules (Clean Architecture default)

```
┌─────────────────────────┐
│  Presentation / Web     │ ─┐
├─────────────────────────┤  │
│  Application (UseCases) │  │ references flow downward
├─────────────────────────┤  │
│  Domain (Entities)      │ <┘ (Domain depends on nothing)
├─────────────────────────┤
│  Infrastructure         │ references Domain + Application
└─────────────────────────┘
```

Customize via `.claude/boundaries.yml` if project uses different
layering (Vertical Slice, Hexagonal, etc.).

## Output

`.claude/audit/boundaries.md`:

```markdown
# Boundary Report

## Violations

### 1. Domain → Infrastructure
- src/MyApp.Domain/Entities/User.cs:3
- `using MyApp.Infrastructure.Email;`
- Fix: inject an `IEmailService` abstraction in Domain, implement in
  Infrastructure

## Cycles

### 1. MyApp.Api ↔ MyApp.Application
- Api → Application (controller uses use-case)
- Application → Api (injects `HttpContext` for tenant resolution)
- Fix: introduce `ITenantContext` in Application; implement in Api
```

## Integration

```
/dotnet:boundaries → .claude/audit/boundaries.md
        ↓
/dotnet:plan "Fix boundary violations"
        ↓
/dotnet:work
```

## References

- `${CLAUDE_SKILL_DIR}/references/clean-architecture.md` — layering
  rules + common refactors
- `${CLAUDE_SKILL_DIR}/references/cycle-breaking.md` — DI inversion,
  interface extraction, events
- `${CLAUDE_SKILL_DIR}/references/namespace-hygiene.md` — `internal`
  vs `public`, `InternalsVisibleTo` policy

## Anti-patterns

- "Fix" by making types `public` (spreads coupling)
- Flagging every cross-layer `using` without context (some are
  intentional)
- Ignoring cycles ("they work at runtime") — they mask compile-time
  signals
