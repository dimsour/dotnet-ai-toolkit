---
name: dotnet:review
description: Review .NET code changes via parallel multi-track review. Spawns dotnet-reviewer, testing-reviewer, security-analyzer, iron-law-judge, verification-runner. Use after /dotnet:work or for PR review.
effort: high
argument-hint: "[--scope <path>] | [--plan <plan.md>]"
---

# /dotnet:review

Thorough multi-track review of .NET code changes. Produces consolidated
verdict in `.claude/plans/{slug}/reviews/consolidated.md` (or
`.claude/reviews/consolidated.md` if no plan).

## When to Use

- After `/dotnet:work` completes
- Before opening a PR
- When user says "review this" / "grill me"
- After large refactor

For single-file review use `dotnet-reviewer` agent directly.

## Iron Laws (review)

1. **Read-only** — reviewers never edit code
2. **Severity wins** — highest severity across tracks is the aggregate
3. **File:line references verbatim** — human must be able to navigate
4. **Verification is a track** — failing build = BLOCK regardless of other
   tracks
5. **Deduplicate findings** — same issue from two tracks = one entry

## Execution Flow

1. **Delegate to `parallel-reviewer`** (opus)
2. Parallel reviewer spawns in ONE dispatch:
   - `dotnet-reviewer` → `reviews/dotnet.md`
   - `testing-reviewer` → `reviews/testing.md`
   - `security-analyzer` → `reviews/security.md`
   - `iron-law-judge` → `reviews/iron-laws.md`
   - `verification-runner` → `reviews/verification.md`
3. After all 5 complete, `context-supervisor` consolidates →
   `reviews/summary.md`
4. Parallel reviewer reads summary, writes verdict →
   `reviews/consolidated.md`
5. Return verdict + path

## Verdict

| Status | Meaning | Next |
|--------|---------|------|
| ✅ APPROVE | Zero critical, verification passes | Ship |
| ⚠️ CHANGES REQUESTED | High/Critical issues, fixable | Fix + re-review |
| ❌ BLOCK | Design flaw, failing build, critical security | Escalate, plan new approach |

## Scoping

| Flag | Scope |
|------|-------|
| default | `git diff HEAD` — staged + working changes |
| `--scope src/Api` | Only files under path |
| `--plan .claude/plans/{slug}/plan.md` | Files touched by this plan (git-log-based) |

## Handoff

After review:

- ✅ APPROVE → `/dotnet:compound` (capture) or open PR
- ⚠️ → `/dotnet:triage` (split findings into work items) or `/dotnet:work`
  with new tasks
- ❌ → `/dotnet:plan --existing` (redesign)

## References

- `${CLAUDE_SKILL_DIR}/references/review-tracks.md` — what each track
  checks
- `${CLAUDE_SKILL_DIR}/references/verdict-rubric.md` — severity mapping
- `${CLAUDE_SKILL_DIR}/references/single-track.md` — when to skip
  parallel and spawn one reviewer

## Single-track shortcuts

Reviewer-specific:

- Idioms only: spawn `dotnet-reviewer`
- Tests only: spawn `testing-reviewer`
- Security only: spawn `security-analyzer`
- Iron Laws only: spawn `iron-law-judge`

## Anti-patterns

- **Running single-track for a large PR** — misses cross-cutting issues
- **Merging before addressing Critical findings**
- **Re-running full review after every small fix** — use
  `/dotnet:verify` for iterative checks, full review once
- **Ignoring verification failures** — build red = block
