---
name: audit
description: Full-project health audit — spawns 5 specialists (dotnet-reviewer, security-analyzer, testing-reviewer, performance-profiler, deployment-validator) in parallel. Use for onboarding or pre-release.
argument-hint: "<optional: specific area to focus>"
effort: high
---

# audit

Comprehensive project assessment. Multi-agent parallel scan with
context-supervisor compression.

## When to Use

- New codebase onboarding — get the full picture fast
- Pre-release go/no-go decision
- Post-incident — what else is lurking
- Quarterly health check

Not for: single-file review (use `/dotnet:review`), or targeted deep
dives (use specific commands).

## Flow

1. **Scope detection** — list solution/projects, frameworks, test
   projects, config files
2. **Spawn 5 specialists in parallel**:
   - `dotnet-reviewer` — C# idioms, async, LINQ, DI, structure
   - `security-analyzer` — OWASP, auth, secrets, injection
   - `testing-reviewer` — coverage gaps, flakiness, isolation
   - `performance-profiler` — EF queries, async bottlenecks, GC
   - `deployment-validator` — Docker, k8s, config hierarchy, probes
3. Each writes findings to `.claude/audit/{agent}.md`
4. **`context-supervisor`** consolidates to `.claude/audit/summary.md`
5. Orchestrator reads ONLY the summary, produces the final report
   with Severity classification and prioritized action list

## Iron Laws

- All 34 apply (this is partly what we're checking for)
- Don't run audit on an uncommitted tree — baseline must be reproducible
- Report must cite file:line for every finding — no unsourced claims

## Severity Rubric

- 🔴 **Critical**: data loss, CVE, auth bypass, production down — fix
  now
- 🟠 **High**: Iron Law violation, likely prod incident — fix before
  release
- 🟡 **Medium**: tech debt, code smell, minor Iron Law nit — schedule
- 🟢 **Low**: style, comments, nice-to-have

## Output

Two artifacts:

1. `.claude/audit/summary.md` — short consolidated report
   (context-supervisor output)
2. `.claude/audit/FULL_REPORT.md` — detailed findings by specialist,
   severity-grouped, with action plan

## Integration

```
/dotnet:audit → .claude/audit/FULL_REPORT.md
        ↓
/dotnet:triage → prioritize + convert to plan tasks
        ↓
/dotnet:plan --existing
```

## References

- `${CLAUDE_SKILL_DIR}/references/audit-scope.md` — what each
  specialist looks for
- `${CLAUDE_SKILL_DIR}/references/severity-examples.md` — concrete
  examples at each severity level
- `${CLAUDE_SKILL_DIR}/references/baseline-metrics.md` — what to
  measure (LOC, coverage, build time, vuln count)

## Anti-patterns

- Running audit and ignoring the output (happens more than you think)
- Treating every finding as Critical — kills credibility
- Skipping context-supervisor step — main context will blow up on
  5-agent raw output
- Running audit on a huge solution without `--scope` filter first
