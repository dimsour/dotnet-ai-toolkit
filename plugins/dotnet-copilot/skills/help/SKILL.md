---
name: help
description: Show available /dotnet:* commands grouped by phase (plan/work/review/analysis/setup/utilities). Use when unsure which command fits.
effort: low
---

# /dotnet:help

Lists the 40 `/dotnet:*` commands grouped by intent. Prints to chat.

## Workflow Commands

| Command | Purpose |
|---------|---------|
| `/dotnet:plan` | Research + decompose a feature into a plan file |
| `/dotnet:brief` | Walk through an existing plan |
| `/dotnet:work` | Execute a plan's tasks |
| `/dotnet:review` | Multi-track review of changes |
| `/dotnet:triage` | Turn review findings into prioritized tasks |
| `/dotnet:full` | Autonomous plan → work → review → compound |
| `/dotnet:quick` | Small change without planning ceremony |
| `/dotnet:verify` | Restore + build + format + test loop |
| `/dotnet:compound` | Capture a solved problem as knowledge |

## Analysis Commands

| Command | Purpose |
|---------|---------|
| `/dotnet:investigate` | Deep root-cause analysis (4 parallel subagents) |
| `/dotnet:challenge` | Grill a design, code, or PR for flaws |
| `/dotnet:brainstorm` | Explore options before committing |
| `/dotnet:learn-from-fix` | Update CLAUDE.md after a correction |
| `/dotnet:document` | Generate/update doc comments, README sections |
| `/dotnet:audit` | Multi-dimension project health check |
| `/dotnet:techdebt` | Identify and prioritize technical debt |
| `/dotnet:boundaries` | Module/namespace coupling check |
| `/dotnet:perf` | Performance analysis + recommendations |
| `/dotnet:pr-review` | Parse PR comments, produce task plan |
| `/dotnet:research` | External docs / library research |

## Setup

| Command | Purpose |
|---------|---------|
| `/dotnet:init` | Create `.claude/` dirs + seed analyzer/editorconfig |
| `/dotnet:intro` | Guided tour of the plugin |

## Utilities

| Command | Purpose |
|---------|---------|
| `/dotnet:nuget-fetcher` | Fetch NuGet package metadata + docs |
| `/dotnet:compound-docs` | Reference for solution-doc schema |
| `/dotnet:examples` | Sample inputs/outputs for each command |
| `/dotnet:permissions` | Reduce repetitive permission prompts |
| `/dotnet:n-plus-one-check` | Scan for EF N+1 risk |
| `/dotnet:migration-check` | Validate pending EF migrations are safe |

## Workflow Patterns

```
Classic:    /dotnet:plan → /dotnet:brief → /dotnet:work → /dotnet:review → /dotnet:compound
Autonomous: /dotnet:full
Small:      /dotnet:quick → /dotnet:verify
Bug fix:    /dotnet:investigate → /dotnet:work → /dotnet:review → /dotnet:compound
Exploration: /dotnet:brainstorm → /dotnet:plan → /dotnet:work → ...
PR comments: /dotnet:pr-review → /dotnet:work → /dotnet:review
```

## Don't Know Where to Start?

- **New to the plugin**: `/dotnet:intro`
- **Feature in mind but unsure size**: describe it, let routing suggest
- **Existing bug**: `/dotnet:investigate`

## References

- `${CLAUDE_SKILL_DIR}/references/quickref.md` — cheat sheet
- `${CLAUDE_SKILL_DIR}/references/chains.md` — common command chains
