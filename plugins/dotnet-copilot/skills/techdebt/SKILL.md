---
name: techdebt
description: Scan for technical debt — TODOs, obsolete APIs, EOL frameworks, nullable warnings suppressed, analyzer warnings silenced, deprecated NuGets. Produces ranked backlog.
argument-hint: <optional: scope path>
effort: medium
---

# techdebt

Surface accumulated debt with concrete remediation estimates.

## What Counts as Tech Debt

- `// TODO`, `// HACK`, `// FIXME` comments (grep + cite)
- `#pragma warning disable` without a comment explaining why
- `[Obsolete]` APIs still in use
- Suppressed nullable warnings (`!` everywhere, `#nullable disable`)
- NuGet packages ≥2 major versions behind
- Target framework EOL (net6.0, netcoreapp3.1, etc.)
- Deprecated EF patterns (`Include` strings, `UseLazyLoadingProxies`
  without intent)
- Synchronous APIs where an async equivalent exists
- Old-style `Startup.cs` on .NET 6+ (should be top-level `Program.cs`)
- Test projects missing `coverlet.collector` or with <50% coverage
- `GlobalSuppressions.cs` / `.editorconfig` rules set to `none`
- `TreatWarningsAsErrors=false` in Release configuration

## Flow

1. **Scan** via Grep / `dotnet list package --outdated` / `.csproj`
   property parsing
2. **Categorize** into: Framework, Dependencies, Code smells,
   Suppressions, Tests, Config
3. **Rank** by impact × ease:
   - 🔴 Security-relevant (EOL framework, unpatched CVE) — top
   - 🟠 Correctness risk (suppressed nullable in hot code) — mid-high
   - 🟡 Maintenance friction (outdated but working) — mid
   - 🟢 Nits — bottom
4. **Estimate** effort per item (S/M/L) with rationale
5. **Output** ranked list → optional `/dotnet:plan` handoff

## Iron Laws

- Fixing debt must not violate Iron Laws (don't suppress a nullable
  warning instead of fixing it)
- Don't classify a business decision as debt (feature flag kept on
  purpose)
- Don't suggest bulk upgrades without checking breaking-change notes

## Output

`.claude/audit/techdebt.md`:

```markdown
# Technical Debt — <date>

## Summary
- Critical: 3
- High: 7
- Medium: 14
- Low: 22

## Critical

### 1. Target framework net6.0 (EOL 2024-11)
- File: Directory.Build.props:3
- Effort: M (2–3 days — test project runner, ASP.NET Core APIs)
- Rationale: security patches stopped
- Fix: bump to net10.0 LTS (current LTS) or net8.0 if constrained

### 2. `Microsoft.AspNetCore.Authentication.JwtBearer` v5.0.17 — CVE-2023-...
- File: src/Api/Api.csproj:12
- Effort: S
- Fix: upgrade to ≥8.0.x
```

## Integration

```
/dotnet:techdebt → .claude/audit/techdebt.md
        ↓
/dotnet:plan "Pay down Critical + High tech debt"
        ↓
/dotnet:work
```

## References

- `${CLAUDE_SKILL_DIR}/references/detection-patterns.md` — grep
  patterns for each debt category
- `${CLAUDE_SKILL_DIR}/references/estimation.md` — S/M/L effort
  rubric with .NET-specific examples
- `${CLAUDE_SKILL_DIR}/references/upgrade-playbooks.md` — common
  multi-step upgrades (net6→net8, EF6→EFCore)

## Anti-patterns

- Flagging every `// TODO` as critical — they're mostly Low
- Suggesting upgrades without CVE/breaking-change context
- Missing tests classified as Critical when the module is dead code
- Bulk "upgrade everything" plan — always prioritize
