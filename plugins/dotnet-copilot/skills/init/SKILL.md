---
name: init
description: Bootstrap a project for the plugin. Creates .claude/ dirs, optionally seeds .editorconfig + analyzers + Directory.Build.props. Use once per repo.
effort: low
---

# /dotnet:init

One-time project bootstrap. Creates the artifact directories the plugin
uses and optionally seeds .NET quality config.

## When to Use

- First time using the plugin in a repo
- After cloning a repo that uses the plugin but missing `.claude/` layout
- When a sub-project inside a monorepo needs its own `.claude/` namespace

## What It Does

### Always

Create (if missing):

```
.claude/
├── plans/
├── reviews/
├── solutions/
│   ├── api-issues/
│   ├── ef-issues/
│   ├── blazor-issues/
│   ├── maui-issues/
│   ├── wpf-issues/
│   ├── di-issues/
│   ├── async-issues/
│   ├── security-issues/
│   ├── perf-issues/
│   ├── deploy-issues/
│   ├── testing-issues/
│   └── nuget-issues/
├── audit/
└── scratchpad/
```

Append to `.gitignore` if missing:

```
# .claude artifacts
.claude/scratchpad/
.claude/plans/*/progress.md
```

(Plans, reviews, solutions ARE committed — they're durable knowledge.)

### Optional (prompt user)

- **Seed `.editorconfig`** if missing — .NET-focused settings
- **Add `Microsoft.CodeAnalysis.NetAnalyzers` + `StyleCop.Analyzers`** to
  `Directory.Build.props`
- **Set `TreatWarningsAsErrors=true`** in `Directory.Build.props`
- **Enable central package management** — create `Directory.Packages.
  props` if missing and prompt
- **Add `global.json`** pinning SDK version
- **Enable `RestorePackagesWithLockFile`** for deterministic restores

## Execution Flow

1. Check repo root (walk up looking for `.sln` / `.csproj` / `.git`)
2. `ls .claude/` — skip creation if already set up
3. `mkdir -p` the tree
4. Append `.gitignore` rules (idempotent — check before appending)
5. For each optional item, ask user Y/n before applying
6. Report: what was created, what was skipped

## Output (chat)

```
✅ .NET plugin initialized

Created:
- .claude/{plans,reviews,solutions/*,audit,scratchpad}
- .gitignore entries (scratchpad, progress.md)

Skipped (already present):
- .editorconfig
- Directory.Build.props

Suggested next steps:
- /dotnet:intro — guided tour
- /dotnet:plan — plan your first feature
```

## References

- `${CLAUDE_SKILL_DIR}/references/editorconfig.md` — recommended settings
- `${CLAUDE_SKILL_DIR}/references/analyzers.md` — analyzer pack choices
- `${CLAUDE_SKILL_DIR}/references/directory-build.md` — shared build
  config template

## Anti-patterns

- **Running repeatedly** — idempotent, but confusing. One time per repo
- **Creating `.claude/` inside another project's `.claude/`** — nested
  namespaces confuse orchestrators
- **Applying opinionated .editorconfig without asking** — teams have
  preferences
