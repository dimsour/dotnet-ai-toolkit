---
name: dotnet:research
description: Research .NET topics externally — docs.microsoft.com, NuGet registry, GitHub issues. Routes to web-researcher or nuget-researcher based on query type.
argument-hint: <topic>  | --library <name>
effort: medium
---

# research

Fetch external context without polluting main conversation. Two
modes.

## Modes

### General topic research

```
/dotnet:research "Blazor United authentication flow"
```

Routes to `web-researcher` (haiku + WebSearch + WebFetch). Prefers:

- `learn.microsoft.com/en-us/dotnet/` (primary)
- `learn.microsoft.com/en-us/aspnet/core/`
- `github.com/dotnet/*` issues + design notes
- `devblogs.microsoft.com/dotnet/`
- Andrew Lock, Nick Chapsas, Scott Hanselman blogs

Output: `.claude/research/{slug}.md` with bullets + authoritative
links.

### Library evaluation

```
/dotnet:research --library Polly
```

Routes to `nuget-researcher`. Returns:

- Current version + last published date
- Maintenance signal (commits / issues / stars / release cadence)
- Known CVEs (`dotnet list package --vulnerable` cross-check)
- Compatibility matrix (target frameworks supported)
- Recommended alternatives if maintenance is stale
- 1–2 representative usage snippets

Output: `.claude/research/libraries/{name}.md`.

## Iron Laws

- Cite sources — never fabricate API names or NuGet versions
- Verify NuGet package identity (`nuget.org/packages/<id>`) before
  recommending
- Flag EOL runtimes when research result assumes them (e.g., snippet
  using `netcoreapp2.1`)
- If CVE found, route to security skill with 🔴 severity

## Flow

1. **Classify** query — general vs library
2. **Spawn** the appropriate researcher agent
3. **Researcher** fetches primary-source URLs, summarizes
4. **Output** structured Markdown file
5. **Return** summary inline (don't dump the full file)

## Example Outputs

### General

```markdown
# Blazor United Authentication (research — 2026-04-18)

## Key concepts
- `@rendermode` affects auth cookie visibility [microsoft-1]
- InteractiveServer: full auth state available
- InteractiveWebAssembly: state persistence via PersistentComponentState
- ...

## Sources
[microsoft-1]: https://learn.microsoft.com/.../blazor/security
[microsoft-2]: ...
```

### Library

```markdown
# Polly v8.4.0 (research — 2026-04-18)

## Summary
- Resilience library: retry, circuit breaker, timeout, bulkhead
- Maintained by App vNext (community)
- Last release: 2026-03-20 (active)
- Stars: 13k, issues: 28 open

## Compatibility
- net6.0, net8.0, net9.0

## CVEs
None (checked GitHub Advisory + dotnet list package --vulnerable)

## Recommendation
✅ Safe to adopt. Prefer Microsoft.Extensions.Http.Resilience (which
wraps Polly v8) for HTTP clients.
```

## References

- `${CLAUDE_SKILL_DIR}/references/trusted-sources.md` — ranked list
  of .NET documentation sources
- `${CLAUDE_SKILL_DIR}/references/nuget-evaluation.md` — signals to
  check for library health
- `${CLAUDE_SKILL_DIR}/references/search-patterns.md` — effective
  queries for docs vs GitHub issues

## Anti-patterns

- Asking main Claude for .NET research when `/dotnet:research` would
  isolate the context
- Recommending an unmaintained library — always check last release
  date
- Pulling random blog content without a primary-source citation
- Not saving research output — loses the work for the next session
