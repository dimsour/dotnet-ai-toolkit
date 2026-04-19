---
name: dotnet:intent-detection
description: Internal — detects user intent from natural-language requests and routes to the right /dotnet:* command. Not user-invocable.
effort: low
user-invocable: false
---

# dotnet:intent-detection

Internal skill used by the plugin to route ambiguous user requests to the
right command. Not invoked directly by users.

## Routing Table

| Signal | Route To |
|--------|----------|
| "plan", "design", "how should I build" | `/dotnet:plan` |
| "make it", "implement", "build me" + clear scope | `/dotnet:work` (if plan exists) or `/dotnet:plan` → `/dotnet:work` |
| "bug", "error", "doesn't work", "crash" | `/dotnet:investigate` |
| "review", "look over", "grill me" | `/dotnet:review` |
| "quick fix", "small change", "typo", single file | `/dotnet:quick` |
| "brainstorm", "ideas", "options", unclear scope | `/dotnet:brainstorm` |
| "research", "compare", "what's available" | `/dotnet:research` |
| "package", "nuget", "library" | `/dotnet:research --library` |
| "test it", "run tests", "verify" | `/dotnet:verify` |
| "I want feature X" + ambiguous size | ask: "plan first or just work on it?" |
| "full feature", "end to end" | `/dotnet:full` |
| "N+1", "slow query" | `/dotnet:n-plus-one-check` |
| "migration", "schema change" | `/dotnet:migration-check` |
| "PR review comments" | `/dotnet:pr-review` |
| "perf", "slow", "bottleneck" | `/dotnet:perf` |
| "tech debt", "cleanup" | `/dotnet:techdebt` |
| "audit", "project health" | `/dotnet:audit` |
| "boundaries", "coupling", "xref" | `/dotnet:boundaries` |
| "permissions", "prompts" | `/dotnet:permissions` |

## Classification Signals

### Scope Size

- **Tiny** (direct edit): 1–2 files, known pattern, <30 LOC
- **Small** (`/dotnet:quick`): <50 LOC, 1–3 files, known pattern
- **Medium** (`/dotnet:plan`): feature-sized, multi-file
- **Large** (`/dotnet:full`): new module or cross-cutting

### Certainty

- **Clear scope + clear approach** → direct edit or `/dotnet:work`
- **Clear scope + unclear approach** → `/dotnet:plan`
- **Unclear scope** → `/dotnet:brainstorm`
- **Bug with unknown cause** → `/dotnet:investigate`

## Suggestion Format

When routing proactively:

```
This looks like {intent}. Want me to run `/dotnet:{command}`, or should
I handle it directly?
```

**One suggestion, then proceed.** Never block the user with repeated
suggestions.

## Rules

1. **Trivial work**: skip suggestion, just do it
2. **One suggestion per first message** — subsequent questions don't
   re-prompt unless scope shifts significantly
3. **User override always wins** — if they say "just do it", proceed
   without ceremony

## Examples

### Example 1: Clear feature

User: "Add cancel button to order detail page"

Classification: clear scope, clear approach, multi-file (probably View + VM + API call)

Route: suggest `/dotnet:plan` for plan trail, or proceed with direct edit
if small.

### Example 2: Vague

User: "Something's wrong with logging"

Classification: bug, unknown root cause

Route: `/dotnet:investigate`

### Example 3: Trivial

User: "Typo in readme"

Classification: trivial, no routing needed. Just edit.
