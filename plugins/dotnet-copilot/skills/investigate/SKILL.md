---
name: investigate
description: Deep bug investigation — spawns 4 parallel subagents (reproduction, root cause, impact, fix strategy) via deep-bug-investigator. Use for complex bugs, race conditions, memory leaks, unclear failures.
argument-hint: <description of bug or failure>
effort: high
---

# investigate

Structured root-cause analysis for complex or recurring bugs.

Use `/dotnet:investigate` when:

- A bug doesn't reproduce locally or has intermittent behavior
- 3+ fix attempts have failed (debugging loop)
- Exception is wrapped/masked by higher layers
- Memory leak, deadlock, or performance cliff
- "Works on my machine" divergence

For simple bugs with obvious fixes, use direct work instead.

## Flow

1. **Gather context** from user: symptom, expected behavior, repro
   steps (even partial), last-working state, stack traces
2. **Spawn `deep-bug-investigator`** (sonnet, 40-turn budget)
3. The investigator dispatches **4 subagents in parallel**:
   - **Reproduction**: isolate minimal failing test/input
   - **Root cause**: trace the bug to its origin in the code
   - **Impact**: identify affected users, data, other code paths
   - **Fix strategy**: propose 1-3 remediation options with trade-offs
4. `context-supervisor` (haiku) consolidates subagent output
5. Orchestrator synthesizes report to `plans/{slug}/investigation.md`

## Iron Laws (for fixes)

Any proposed fix must not violate the 34 Iron Laws. Pay special
attention to:

- **#2**: Don't "fix" an async bug by adding `.Result`
- **#11**: Don't "fix" perf by disabling `.Include` (forces N+1)
- **#28**: Don't paper over an auth bug by exposing more in appsettings
- **#34**: Don't claim fixed without `dotnet build && dotnet test`

## Input

- Textual description of the symptom
- Optional: stack trace, log snippets, repro repo

## Output

`plans/{slug}/investigation.md` — structured findings:

```markdown
# Investigation: <bug>

## Reproduction
- Minimal case: ...
- Trigger conditions: ...

## Root Cause
- File: src/Services/OrderService.cs:142
- Mechanism: ...
- Introduced in commit: <sha>

## Impact
- Direct: ...
- Related code paths: ...

## Fix Options
| Option | Complexity | Risk | Recommendation |
|--------|------------|------|----------------|
| ...    | low        | low  | ✅ Preferred    |
```

## Integration

```
/dotnet:investigate → plans/{slug}/investigation.md
                          ↓
/dotnet:plan --existing plans/{slug}/investigation.md
                          ↓
/dotnet:work
```

## References

- `${CLAUDE_SKILL_DIR}/references/investigation-flow.md` — subagent
  coordination details
- `${CLAUDE_SKILL_DIR}/references/evidence-collection.md` — what to
  gather before escalating
- `${CLAUDE_SKILL_DIR}/references/common-causes.md` — async deadlocks,
  DbContext lifetime, GC pressure, captive deps

## Anti-patterns

- Using `/dotnet:investigate` for obvious bugs (wastes agent budget)
- Not providing stack trace when one exists
- Applying proposed fix without running existing test suite first
- Marking investigation "complete" without verification (Iron Law #34)
