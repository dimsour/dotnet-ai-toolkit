---
name: dotnet:verify
description: Run .NET verification loop — restore → build → format → test → analyzer pass. Discovers solution/projects from .sln/global.json. Use after edits or before commit.
effort: low
argument-hint: "[<project or solution path>]"
---

# /dotnet:verify

Fast quality gate. Delegates to `verification-runner` agent.

## When to Use

- After any non-trivial edit
- Before commit / push
- Iron Law #34: never claim done without verify output

## Iron Laws (verify)

1. **Always scope** — if you changed one project, verify only that project
2. **Report pre-existing failures separately** — don't panic if the
   solution already had broken tests
3. **Failure → fix root cause, don't skip** — never `--no-verify` or
   `--filter` to bypass
4. **Verify output IS the claim** — paste the result, don't summarize

## Execution Flow

Delegates to `verification-runner` (haiku, effort:low). Runner does:

1. **Discovery**: `.sln` / `global.json` / `Directory.Build.props` /
   project `.csproj` metadata
2. **Restore**: `dotnet restore` — fail on NU-series errors
3. **Build**: `dotnet build --no-restore -c Debug`
4. **Format**: `dotnet format --verify-no-changes --no-restore` —
   report-only, don't apply
5. **Test**: `dotnet test --no-build --verbosity minimal`
6. **Analyzer pass** (optional): `dotnet build -warnaserror` scoped to
   changed projects
7. **Vulnerable packages** (optional, pre-PR): `dotnet list package
   --vulnerable --include-transitive`

## Output

`.claude/reviews/verification.md` (default) or path from argument. Format:

```markdown
# Verification Report

## Project Config
Solution: MyApp.sln, SDK net8.0, Warnings-as-errors: true

## Summary

| Step | Status | Details |
|------|--------|---------|
| Restore | ✅ | |
| Build | ✅ | 0 errors |
| Format | ✅ | |
| Test | ✅ | 142/142 |
| Analyzers | ⏭ | skipped (scoped) |
| Vulnerable packages | ✅ | none |

## Overall: ✅ PASS
```

## Additional Tests Offer

If the solution has integration/e2e/load test projects, the runner offers:

```
Core verification passed. Additional test commands:
1. dotnet test tests/MyApp.IntegrationTests
2. dotnet test tests/MyApp.LoadTests
3. dotnet list package --outdated
Run any? [1/2/3/all/skip]
```

## Handoff

- ✅ PASS → safe to proceed
- ❌ FAIL → read failure details; common failures auto-hinted by
  `dotnet-failure-hints.sh`
- Repeated failure → `/dotnet:investigate`

## References

- `${CLAUDE_SKILL_DIR}/references/discovery.md` — how the runner picks
  projects
- `${CLAUDE_SKILL_DIR}/references/failure-patterns.md` — common dotnet
  error → fix
- `${CLAUDE_SKILL_DIR}/references/integration-tests.md` — additional test
  modes

## Anti-patterns

- **Verifying full solution** when you only touched one project — slow
- **Ignoring analyzer warnings** that are new in your change
- **Claiming "tests pass"** without verify output shown (Iron Law #34)
