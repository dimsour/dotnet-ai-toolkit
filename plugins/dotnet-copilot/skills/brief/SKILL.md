---
name: brief
description: Walkthrough a plan file interactively. Reads plan.md and explains decisions, task flow, and risks section by section without executing. Use before /dotnet:work on unfamiliar plans.
effort: medium
argument-hint: <plan.md path>
---

# /dotnet:brief

Interactive walkthrough of a plan file. No code changes. Helps the user
understand what `/dotnet:work` will do before committing to execution.

## When to Use

- You just got a plan from `planning-orchestrator` and want a narrated
  read
- Resuming a plan written by a previous session
- Reviewing a teammate's plan
- Before `/dotnet:work` on any Large-scope plan

## Iron Laws (briefing)

1. **Read-only** — no edits, no execution
2. **Narrative mode** — explain, don't just read
3. **Surface risks** — highlight Iron Law implications + risks sections
4. **Identify ambiguity** — if a task is vague, flag it

## Execution Flow

1. Read `plan.md` at the argument path
2. Read sibling files if present (`research/*.md`, `summaries/*.md`)
3. Produce structured walkthrough:
   - **Context**: what this plan solves + why now
   - **Scope**: in/out
   - **Decisions**: each tech choice + rationale
   - **Task breakdown**: phases summarized (not every task)
   - **Iron Law touchpoints**: which tasks risk which laws
   - **Risks**: from plan's risks section + your own flags
   - **Open questions**: anything underspecified
4. Ask the user: "Ready to `/dotnet:work`, or refine the plan first?"

## Output (chat, no file)

Keep the walkthrough under 500 words. Bullet-heavy. Link to plan file for
detail.

## Handoff

- "Ready" → `/dotnet:work {plan}`
- "Needs refinement" → `/dotnet:plan --existing {plan}`
- "Wrong approach" → `/dotnet:plan` with corrected description

## References

- `${CLAUDE_SKILL_DIR}/references/walkthrough-template.md` — the
  narrative shape
- `${CLAUDE_SKILL_DIR}/references/risk-surface.md` — how to read for
  risks

## Anti-patterns

- **Reciting the plan verbatim** — the user can read it. Brief =
  interpret
- **Silent agreement** — if a plan has a hidden gap, say so
- **Suggesting implementation** — that's `/dotnet:work`'s job
