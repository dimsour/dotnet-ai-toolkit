---
name: triage
description: Convert a review verdict into prioritized work items. Reads consolidated.md, splits findings into tasks grouped by severity, produces a triage plan. Use after /dotnet:review.
effort: medium
argument-hint: [<consolidated.md path>]
---

# /dotnet:triage

Turns a review's findings into a prioritized plan. No code changes.

## When to Use

- After `/dotnet:review` returns ⚠️ CHANGES REQUESTED with N findings
- After PR review comments land and you want structured fixes
- When multiple reviews stacked and you need priorities

## Iron Laws (triage)

1. **Preserve file:line references** — fix paths must survive triage
2. **Severity drives order** — Critical/High first, Medium next, Low
   deferred or tracked
3. **Group by file/module** — related fixes in the same task reduce thrash
4. **Distinguish must-fix vs nice-to-have** — triage is about scoping

## Execution Flow

1. Read `consolidated.md` (argument or auto-detect latest
   `.claude/plans/*/reviews/consolidated.md` or `.claude/reviews/
   consolidated.md`)
2. Parse findings:
   - Severity (🔴 / 🟠 / 🟡 / 🟢)
   - File:line
   - Track source (dotnet/testing/security/iron-laws/verification)
   - Suggested fix
3. Group:
   - By severity (all Critical first)
   - Within severity: by file/module (co-locate fixes)
4. Produce triage output at `.claude/plans/{slug}/triage.md`:

```markdown
# Triage: {slug}

## Must-Fix (Critical + High)

### 1. [P1-T1][security] Fix SQL injection in OrdersController.GetByEmail
**File**: src/Api/OrdersController.cs:87
**Source**: security-analyzer, iron-law-judge (#26)
**Fix**: Use `.Where(x => x.Email == email)` (parameterized)

### 2. [P1-T2][ef] Add AsNoTracking + Include before Where
**File**: src/Services/OrderService.cs:42
**Source**: iron-law-judge (#6, #9)
**Fix**: See review — reorder Include/Where, add AsNoTracking

## Should-Fix (Medium)

### 3. [P2-T1][direct] ...

## Track Later (Low)

Listed but not scheduled. Convert to GitHub issues if desired.

## Not Fixing

Findings rejected with rationale.
```

5. Offer: `/dotnet:work .claude/plans/{slug}/triage.md` to execute the
   triage plan

## Handoff

- `/dotnet:work triage.md` — start fixing Critical/High
- `/dotnet:plan --existing triage.md` — promote to full plan if complex
- Open GitHub issues for deferred Low items

## References

- `${CLAUDE_SKILL_DIR}/references/triage-rubric.md` — Must/Should/Could
  classification rules
- `${CLAUDE_SKILL_DIR}/references/severity-mapping.md` — how tracks'
  severities map to triage priority

## Anti-patterns

- **Triaging without reading findings carefully** — blanket classification
- **Demoting valid Critical findings** to make the list shorter
- **Merging unrelated fixes into one task** — harder to review, harder
  to revert
