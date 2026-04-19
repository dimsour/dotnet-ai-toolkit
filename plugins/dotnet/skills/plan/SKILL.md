---
name: dotnet:plan
description: Plan a .NET feature before coding. Spawns planning-orchestrator which researches, decomposes tasks, and writes `.claude/plans/{slug}/plan.md`. Use for any non-trivial change.
effort: high
argument-hint: <feature description> | --existing <plan.md>
---

# /dotnet:plan

Produces a reviewable plan file at `.claude/plans/{slug}/plan.md` before
any code is written.

## When to Use

| Signal | Use /dotnet:plan? |
|--------|-------------------|
| Feature touches >3 files | Yes |
| New entity / API / UI surface | Yes |
| Refactor crossing module boundaries | Yes |
| Unclear scope | Yes (scope classification is the first output) |
| Single-line fix | No — use `/dotnet:quick` |
| Bug debugging | No — use `/dotnet:investigate` |
| Pure question ("how does X work") | No — answer directly |

## Iron Laws (planning)

1. **No implementation during planning** — plan is about decisions, not
   code
2. **Cite code with `file:line`** — vague plans fail at execution
3. **Every task is imperative** — "Add validator" not "Should validate"
4. **Classify scope** — Tiny / Small / Medium / Large drives
   orchestration depth
5. **Surface Iron Law implications at plan time** — don't defer to review

## Execution Flow

1. **Delegate to `planning-orchestrator`** (opus)
   - Subagent reads request, scans codebase
   - Spawns domain specialists in parallel (ef-schema-designer,
     api-architect, blazor-architect, etc. — only those relevant)
   - Runs `context-supervisor` to compress research
   - Drafts `plan.md`
2. **For Large scope**: orchestrator spawns Decision Council (dotnet-reviewer
   - one or two specialists) to critique the plan before you see it
3. **Return**: plan path, scope classification, task count, next command

## Variants

### Enhance existing plan

```
/dotnet:plan --existing .claude/plans/{slug}/plan.md
```

Research gaps, add missing tasks, flag risks. Doesn't rewrite — annotates.

### Plan from triage

`/dotnet:triage` turns a review verdict into ready-to-work plans. Call
plan to expand/refine a single triaged item.

## Handoff

After plan written:

- `/dotnet:brief .claude/plans/{slug}/plan.md` — walk through the plan
  interactively (optional)
- `/dotnet:work .claude/plans/{slug}/plan.md` — start execution
- `/dotnet:full` — full lifecycle (plan + work + review + compound)

## References

- `${CLAUDE_SKILL_DIR}/references/planning-workflow.md` — end-to-end flow
- `${CLAUDE_SKILL_DIR}/references/plan-template.md` — the `plan.md`
  structure
- `${CLAUDE_SKILL_DIR}/references/complexity-detail.md` — Tiny/Small/
  Medium/Large heuristics
- `${CLAUDE_SKILL_DIR}/references/agent-selection.md` — which research
  agents to spawn for which signals
- `${CLAUDE_SKILL_DIR}/references/breadboarding.md` — rough-sketch
  architecture before detail

## Anti-patterns

- **Planning the obvious** — don't plan a 5-line fix
- **Research theater** — spawning 5 agents when 1 is enough
- **"Investigate X"** as a task — decide in research phase
- **Copying the plan template without thinking** — each section must
  have real content
