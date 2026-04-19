---
name: dotnet:compound-docs
description: Schema + conventions for compound solution docs. Used by /dotnet:compound to write durable problem→solution records in .claude/solutions/{category}/.
effort: low
user-invocable: false
---

# compound-docs

Reference for the Solution Doc format used by the compound knowledge
system.

## Filesystem Layout

```
.claude/solutions/
├── ef-issues/
│   ├── n-plus-one-in-order-list.md
│   └── concurrent-update-conflict.md
├── api-issues/
│   ├── over-posting-in-dto.md
│   └── missing-authorize-on-delete.md
├── blazor-issues/
├── maui-issues/
├── wpf-issues/
├── di-issues/
├── async-issues/
├── security-issues/
├── perf-issues/
├── deploy-issues/
└── build-issues/
```

## File Schema (YAML frontmatter + Markdown body)

```markdown
---
title: N+1 query in order list endpoint
category: ef-issues
tags: [ef-core, n-plus-one, include, performance]
date: 2026-04-18
project: myapp
severity: high
time_to_fix: 20m
iron_laws: [11, 6]
---

## Problem

GET /api/orders took 1.8s p99. DB log showed N queries for customer
lookup, one per order.

## Symptoms

- Observed: p99 latency 1.8s
- Expected: <200ms
- Trigger: GET /api/orders with ≥50 records

## Root Cause

`src/Api/Orders/OrdersController.cs:47` iterates orders and accesses
`.Customer.Name` with lazy loading enabled → one query per order.

```csharp
foreach (var o in orders)
    result.Add(new { o.Id, Customer = o.Customer.Name }); // N+1
```

## Fix

Project to DTO inside the query — one SQL, no navigation after
materialization:

```csharp
var result = await _ctx.Orders
    .AsNoTracking()
    .Select(o => new OrderSummaryDto(o.Id, o.Customer.Name))
    .ToListAsync(ct);
```

## Verification

- Added integration test asserting ≤2 queries via logging interceptor
- BenchmarkDotNet: 1.8s → 120ms p99

## Related

- Iron Law #11 (no N+1)
- Iron Law #6 (AsNoTracking on reads)
- See also: `ef-issues/projection-over-include.md`

```

## Required Fields

- `title` — short problem statement
- `category` — one of the layout folders above
- `tags` — 3–6 searchable tags, lowercase
- `date` — ISO 8601
- `severity` — low / medium / high / critical
- `iron_laws` — list of violated law numbers (empty `[]` if none)

Optional:

- `project` — if multiple projects in one workspace
- `time_to_fix` — human-readable estimate
- `related` — paths to other solution docs

## Naming Convention

`{short-slug}.md` — kebab-case, verb-oriented, unique within category.
Good: `n-plus-one-in-order-list.md`. Bad: `fix.md`, `bug-23.md`.

## Usage by `/dotnet:compound`

The compound skill:

1. Reads the just-finished fix (git diff / plan progress)
2. Classifies by category (which domain did the bug live in)
3. Generates the solution doc in this schema
4. Writes to `.claude/solutions/{category}/{slug}.md`

## Integration

```

/dotnet:work (fix landed)
        ↓
/dotnet:compound → .claude/solutions/{category}/{slug}.md
        ↓
future /dotnet:plan / /dotnet:investigate searches solutions/

```

## References

- `${CLAUDE_SKILL_DIR}/references/schema.md` — full field reference
- `${CLAUDE_SKILL_DIR}/references/categories.md` — when to pick each
  folder
- `${CLAUDE_SKILL_DIR}/references/example-solution.md` — full worked
  example

## Anti-patterns

- Missing `iron_laws` field — breaks cross-referencing
- Vague titles ("bug fix", "tuning") — not searchable
- Dumping a git diff without the Problem / Root Cause / Fix narrative
- Writing solution docs for one-off issues unlikely to recur
