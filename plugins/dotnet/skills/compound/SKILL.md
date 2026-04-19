---
name: dotnet:compound
description: Capture a solved problem as institutional knowledge. Writes `.claude/solutions/{category}/{slug}.md` with symptoms, root cause, fix, category, tags. Use after notable fixes.
effort: low
argument-hint: [<problem summary>]
---

# /dotnet:compound

Captures what you learned solving a non-obvious problem. The solution
becomes searchable knowledge future sessions can find.

## When to Use

- After fixing a stubborn bug (root cause matters beyond this instance)
- After discovering a non-obvious pattern / Iron Law edge case
- After resolving an intermittent failure
- After adopting a new library with surprising behavior

**Do NOT use for:**

- Trivial fixes (typo, wrong string)
- Fixes already documented in ADRs or team docs
- Features that worked as expected

## Iron Laws (compound)

1. **One problem per solution doc** — mixing dilutes findability
2. **Root cause, not symptom** — "wrong env" ≠ "DbContext captured in
   Singleton"
3. **Category chosen deliberately** — see list below; don't create new
   categories casually
4. **Tags must be searchable terms** — future-you types these

## Categories

- `ef-issues/` — EF Core, migrations, query, tracking bugs
- `api-issues/` — ASP.NET Core Web API, middleware, routing
- `blazor-issues/` — Blazor components, render modes, interop
- `maui-issues/` — MAUI cross-platform bugs
- `wpf-issues/` — WPF binding, XAML, commanding
- `di-issues/` — lifetime bugs, captive deps, DI config
- `async-issues/` — async/await, threading, cancellation
- `security-issues/` — auth, JWT, CORS, secrets
- `perf-issues/` — N+1, GC, allocation, async bottlenecks
- `deploy-issues/` — Docker, K8s, Azure, IIS
- `testing-issues/` — flaky tests, isolation, fixtures
- `nuget-issues/` — package conflicts, transitive deps, CVEs

## Execution Flow

1. **Detect context** — user just fixed something, or invoked
   `/dotnet:compound` directly
2. **Ask if needed**:
   - What was the symptom?
   - What was the root cause?
   - What was the fix?
   - (inferred from git diff if recent work)
3. **Classify**: pick a category
4. **Generate slug** — kebab-case, 3–5 words
5. **Write** `.claude/solutions/{category}/{slug}.md`:

```markdown
---
problem: One-sentence problem statement
symptoms:
  - User-observed
  - Logs / metrics
root_cause: One-sentence root cause
fix: One-sentence fix
category: ef-issues
tags: [efcore, include, n-plus-one]
date: 2026-04-18
related:
  - .claude/solutions/ef-issues/other-slug.md
---

# {Problem title}

## Symptoms

- {observable}
- {from logs}

## Root Cause

{The underlying mechanism. What was really happening.}

## Fix

​```csharp
// Before
var orders = await _db.Orders.ToListAsync();
foreach (var o in orders)
    o.Items = await _db.OrderItems.Where(...).ToListAsync();

// After
var orders = await _db.Orders
    .AsNoTracking()
    .Include(o => o.Items)
    .AsSplitQuery()
    .ToListAsync(ct);
​```

## Why the Original Failed

{Mechanism-level explanation.}

## How to Recognize This

{Clues for future detection — error messages, symptoms, patterns in code.}

## References

- Iron Laws: #6, #9, #11
- Plan: `.claude/plans/{slug}/plan.md` (if any)
- PR: {url if known}
```

6. **Confirm** with user: path written, summary printed

## Search Later

Future Claude sessions can grep `.claude/solutions/` for tags/symptoms
when confronting similar issues. The frontmatter makes mechanical search
easy.

## References

- `${CLAUDE_SKILL_DIR}/references/schema.md` — full frontmatter schema
- `${CLAUDE_SKILL_DIR}/references/categories.md` — when to use which
- `${CLAUDE_SKILL_DIR}/references/examples.md` — sample solution docs

## Anti-patterns

- **Vague root causes** — "the code was wrong" teaches nothing
- **Sharing multiple problems in one doc** — split them
- **Missing the "how to recognize"** section — this is what makes future
  matching possible
- **Creating a new category for one-off** — use closest existing
