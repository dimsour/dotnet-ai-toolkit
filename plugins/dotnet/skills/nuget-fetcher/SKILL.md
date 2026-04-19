---
name: dotnet:nuget-fetcher
description: Fetch NuGet package metadata, versions, vulnerabilities, compat matrix, and deprecation status. Supports dotnet list package and NuGet.org v3 API.
argument-hint: <package name> [--version <v>]
effort: low
---

# nuget-fetcher

Retrieve concrete NuGet package facts — no hallucinated versions or
APIs.

## Primary Commands

```bash
# In a project directory
dotnet list package                              # installed
dotnet list package --outdated                   # available upgrades
dotnet list package --vulnerable --include-transitive
dotnet list package --deprecated

# Global / without project
# v3 Registration index
curl -s "https://api.nuget.org/v3/registration5-semver1/<id>/index.json"
# Service discovery
curl -s "https://api.nuget.org/v3/index.json"
# Catalog (historical releases)
curl -s "https://api.nuget.org/v3/catalog0/index.json"
```

## What to Retrieve

Per package:

- Latest stable version + pre-release if diverged
- Publish date of latest version
- Supported target frameworks (from .nuspec)
- Dependencies (direct only — deep trees are noise)
- License + license expression
- Repository URL + last-commit signal
- Known CVEs (via `--vulnerable` or GitHub Advisory)
- Deprecation status

## Flow

1. **Normalize** package id (case-insensitive on NuGet.org)
2. **Query** NuGet.org registration endpoint OR use `dotnet list
   package` inside the project
3. **Extract** version, frameworks, deps, license
4. **Cross-check** CVE via `dotnet list package --vulnerable`
5. **Output** compact summary — not raw JSON

## Iron Laws

- Never fabricate a version number
- Verify the package id exactly (typosquatting risk)
- Flag `--vulnerable` matches as security-critical
- Prefer official MS-owned packages when equivalent community package
  is unmaintained

## Output Template

```markdown
# Polly — NuGet metadata

| Field | Value |
|-------|-------|
| Latest | 8.4.0 (stable) |
| Published | 2026-03-20 |
| Target frameworks | net6.0, net8.0, net9.0 |
| License | BSD-3-Clause |
| Repository | github.com/App-vNext/Polly |
| Vulnerabilities | none |
| Deprecated | no |

## Direct deps (latest)
- Microsoft.Bcl.AsyncInterfaces ≥ 6.0.0

## Notable
- v8 is a major rewrite with breaking API changes from v7
- `Microsoft.Extensions.Http.Resilience` wraps Polly for HttpClient
```

## Integration

Used by:

- `nuget-researcher` agent (library evaluation)
- `/dotnet:research --library` skill
- `/dotnet:plan` when evaluating deps
- `audit` / `techdebt` skills

## References

- `${CLAUDE_SKILL_DIR}/references/nuget-api.md` — v3 endpoints,
  registration, flat container, search
- `${CLAUDE_SKILL_DIR}/references/vuln-sources.md` — GHSA, NuGet
  advisories, `--vulnerable` limits
- `${CLAUDE_SKILL_DIR}/references/framework-monikers.md` — TFM
  compatibility reference

## Anti-patterns

- Returning raw JSON — users want the summary
- Ignoring `--vulnerable` results
- Not distinguishing stable from pre-release when user asked for
  stable
- Recommending a package without verifying its id exactly
