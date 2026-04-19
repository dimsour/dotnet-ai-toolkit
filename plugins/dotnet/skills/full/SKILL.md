---
name: dotnet:full
description: Autonomous end-to-end .NET feature delivery — plan → work → review → compound. Spawns workflow-orchestrator. Use for 30min+ features where you want hands-off execution.
effort: high
argument-hint: <feature description>
---

# /dotnet:full

Runs the complete lifecycle autonomously: plan, execute, review, capture
knowledge — with minimal user intervention.

## When to Use

- New feature taking 30+ minutes of wall time
- User explicitly wants autonomous delivery
- Scope is clear enough to plan without back-and-forth

**Do NOT use for:**

- Exploration / unclear scope — use `/dotnet:brainstorm` first
- Bug fixes — use `/dotnet:investigate`
- Small changes — direct editing or `/dotnet:quick`
- Things requiring architectural decisions the user wants to weigh in on

## Iron Laws (autonomous execution)

1. **One agent orchestrates** — workflow-orchestrator owns the whole cycle
2. **Filesystem is state** — `.claude/plans/{slug}/progress.md` is the log;
   user can check in at any time
3. **Iron Laws non-negotiable** — if a task would violate, fix the plan,
   don't break laws
4. **Destructive ops still require confirmation** — drops, force-pushes,
   prod changes → ask
5. **Max 2 review→fix loops** — if still blocked, surface to user

## Execution Flow

1. **Delegate to `workflow-orchestrator`** (opus, 80 turns)
2. Orchestrator runs:
   - Phase 1: spawn `planning-orchestrator`
   - Phase 2: execute tasks (routing via annotations)
   - Phase 3: spawn `parallel-reviewer` → consolidate
   - Phase 4: optionally spawn `compound` (if notable learning)
3. Between phases, orchestrator:
   - Updates `progress.md` state
   - Runs `verification-runner` for regression catch
   - Writes dead ends to `scratchpad.md`
4. Emits short user-facing update at each phase transition

## User Interaction

The orchestrator stays silent unless:

- Asking a blocking question (design decision, destructive op auth)
- Escalating a stuck state (3+ failures, max loops hit)
- Finishing

Otherwise watch `progress.md` for live status.

## Auto-Resume

If session ends mid-flight:

1. Re-invoke `/dotnet:full --continue` (or just `/dotnet:work --continue`
   with the plan path)
2. Orchestrator reads `progress.md` state, resumes from last phase
3. `scratchpad.md` dead ends prevent repeating failures

## Output

`.claude/plans/{slug}/`:

- `plan.md` — the plan (checkboxes show execution state)
- `progress.md` — narrative log
- `scratchpad.md` — decisions, dead ends, handoffs
- `research/` — specialist research outputs
- `reviews/consolidated.md` — final verdict
- `solutions/` — compound knowledge (if captured)

## Handoff

After `/dotnet:full` finishes:

- If verdict ✅ APPROVE: open PR; solution captured
- If ⚠️ CHANGES REQUESTED (after 2 loops): user reviews consolidated.md,
  decides next steps
- If ❌ BLOCK: user + orchestrator discuss redesign

## References

- `${CLAUDE_SKILL_DIR}/references/lifecycle.md` — phase-by-phase
- `${CLAUDE_SKILL_DIR}/references/resume-semantics.md` — auto-resume
  behavior
- `${CLAUDE_SKILL_DIR}/references/supervision.md` — context supervisor
  pattern usage

## Anti-patterns

- **Using `/dotnet:full` for a 2-file change** — overkill
- **Skipping Phase 3 review** — unreviewed code is incomplete
- **Running two `/dotnet:full` in parallel** — state file collisions
- **Not checking `progress.md`** between long-running phases
