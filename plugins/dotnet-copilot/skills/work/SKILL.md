---
name: work
description: Execute a plan file. Parses task annotations ([direct]/[ef]/[api]/[blazor]/[test]/[security]), routes to specialists, updates checkboxes, writes progress.md. Use after /dotnet:plan.
effort: high
argument-hint: "<plan.md path> | --continue"
---

# /dotnet:work

Executes tasks from a plan file in sequence, routing each task to the
right subagent based on its annotation tag.

## When to Use

- After `/dotnet:plan` produced a plan file
- Resuming a paused plan (`--continue`)
- NOT for ad-hoc changes — use direct editing

## Iron Laws (execution)

1. **Follow the plan** — don't drift scope without updating `plan.md`
2. **Update progress** — mark checkboxes `[x]`, append to `progress.md`
3. **Run `verification-runner` between phases** — catch regressions early
4. **Write dead ends to `scratchpad.md`** — avoid repeating failures
5. **Iron Laws are non-negotiable** — if a task would violate, STOP, fix
   the plan, consult specialist
6. **Verify before claiming done** (Iron Law #34) — `dotnet build && dotnet
   test` output required

## Task Annotation Tags

| Tag | Specialist | Flow |
|-----|-----------|------|
| `[direct]` | none (main agent) | Edit directly |
| `[ef]` | ef-schema-designer | Design → edit → `dotnet ef migrations add` → verify |
| `[api]` | api-architect | Design → edit → verify (build + integration test) |
| `[blazor]` | blazor-architect | Design → edit → verify |
| `[maui]` | maui-specialist | Design → edit → verify (build targets) |
| `[wpf]` | wpf-specialist | Design → edit → verify |
| `[test]` | testing-reviewer (optional) | Write test → run verification-runner |
| `[security]` | security-analyzer | Analyze BEFORE edit → edit → re-analyze |
| `[doc]` | none | Direct edit |
| `[perf]` | performance-profiler | Analyze → edit → benchmark |

## Execution Flow

1. **Load plan**: read `plan.md`, find first unchecked task
2. **Parse annotation**: `[P{phase}-T{n}][{tag}] {description}`
3. **Dispatch**:
   - If `[direct]` / `[doc]`: edit yourself
   - Otherwise: spawn the mapped specialist first for design, then edit
4. **Verify** after each task if the tag is code-producing:
   - Quick check: `dotnet build` on affected project
   - Full verification at end of each phase
5. **Update state**:
   - Check the box: `- [ ]` → `- [x]` in `plan.md`
   - Append to `progress.md`: what, files, outcome
   - If stuck 2+ attempts: write "Dead End: {approach} — {why}" to
     `scratchpad.md`
6. **Loop** until all tasks checked or blocked

## `--continue` Mode

Resume after interruption:

1. Read `plan.md` — find first unchecked task
2. Read `progress.md` — understand prior state
3. Read `scratchpad.md` — avoid known dead ends
4. Proceed from next unchecked task

## Stuck Detection

If 3+ consecutive failures (compile / test / format):

1. Write to `scratchpad.md`
2. Spawn `deep-bug-investigator` (structured root-cause)
3. OR surface blocker to user with options

The `error-critic.sh` hook automatically detects dotnet command failures
and escalates from hints to critic analysis.

## Progress Format

```markdown
## P1-T3 [api] Add POST /api/v1/orders

**Status**: Complete
**Files changed**: src/Api/OrdersEndpoints.cs (new), src/Api/Program.cs
**Specialist**: api-architect (design → .claude/plans/{slug}/research/api.md)
**Verification**: build ✅, tests ✅ (3 new)
**Time**: 14m
```

## Handoff

After all tasks checked:

- `/dotnet:review` — thorough multi-track review
- `/dotnet:verify` — quick build + test + format
- `/dotnet:compound` — capture learnings

## References

- `${CLAUDE_SKILL_DIR}/references/execution-flow.md` — detailed state
  machine
- `${CLAUDE_SKILL_DIR}/references/tag-routing.md` — full routing table
- `${CLAUDE_SKILL_DIR}/references/stuck-recovery.md` — when and how to
  escalate

## Anti-patterns

- **Running multiple tasks before checking the first** — lose traceability
- **Skipping verification between phases** — regressions compound
- **Editing files not in plan** — drift scope; update plan first
- **Not updating progress.md** — impossible to resume
