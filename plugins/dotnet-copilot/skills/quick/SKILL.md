---
name: quick
description: Small, low-risk change — skips planning ceremony, edits directly, runs verify at end. Use for <50 LOC changes, CSS/UI tweaks, config updates, obvious bug fixes.
effort: low
argument-hint: <what to change>
---

# /dotnet:quick

Fast path for tiny changes. No planning, no research agents, no reviews —
just edit, verify, done.

## When to Use

- <50 LOC
- Single file (or 2–3 files, same module)
- Pattern already exists in codebase (copy-adapt)
- Obvious bug (typo, wrong condition, off-by-one)
- Config value change (with understanding of impact)
- Doc / comment update

**Do NOT use for:**

- New features — use `/dotnet:plan`
- Cross-cutting refactors
- Security-sensitive changes (even small ones need `/dotnet:review`)
- Changes you're unsure about — use `/dotnet:brainstorm` first

## Iron Laws (quick path)

1. **Scope discipline** — one thing, one file-ish, one commit-worthy
   change
2. **Iron Laws still apply** — no shortcut for `.Result`, SQL interp,
   etc.
3. **Verify at end** — `dotnet build && dotnet test` on scope
4. **Sibling check** — if you fixed a named variant
   (`BuyerController.cs`), grep for siblings (`SellerController.cs`,
   `AdminController.cs`) — same bug may exist

## Execution Flow

1. **Confirm scope** — verify request fits "quick" criteria. If in doubt,
   flip to `/dotnet:plan`
2. **Read relevant file(s)**
3. **Edit** directly
4. **Sibling check** — grep for similar files/patterns
5. **Verify**:
   - `dotnet build` on affected project
   - `dotnet test` on affected test project (if exists)
   - `dotnet format --verify-no-changes --include {files}`
6. **Report**: what changed, where, verification result

## Output (chat, no file)

```
✅ Quick change applied.

Files: src/Api/HealthEndpoints.cs:42 (changed 'ready' → 'readiness')
Build: ✅
Tests: ✅ 3/3 in Api.Tests
Format: ✅
```

## Escalation

If during execution you discover:

- The change is bigger than expected → STOP, switch to `/dotnet:plan`
- Multiple Iron Laws at play → STOP, discuss with user
- Sibling files affected → update all OR write a proper plan

## References

- `${CLAUDE_SKILL_DIR}/references/scope-check.md` — quick-fit criteria

## Anti-patterns

- **Sneaking in extra refactoring** — out of scope; write a follow-up task
- **Skipping verify** — "it's just a typo" ≠ "it builds"
- **Missing sibling files** — fixing `Buyer.cs` but not `Seller.cs` when
  both have the same bug
