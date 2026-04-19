---
name: dotnet:pr-review
description: Review a pull request — fetches diff via gh, spawns parallel-reviewer. Produces structured feedback grouped by severity with file:line citations.
argument-hint: <PR number or URL>
effort: high
---

# pr-review

Structured review of a GitHub pull request using the parallel-reviewer
multi-agent pipeline.

## Prerequisites

- `gh` CLI installed and authenticated
- Repo identifiable from current directory OR PR URL provided

## Flow

1. **Fetch PR metadata**:

   ```bash
   gh pr view <number> --json title,body,files,commits,baseRefName,headRefName
   gh pr diff <number>
   ```

2. **Check out the branch** (or work from diff if read-only review)
3. **Spawn `parallel-reviewer`** which in turn spawns 5 reviewers in
   parallel:
   - `dotnet-reviewer` — C# idioms
   - `security-analyzer` — OWASP
   - `testing-reviewer` — test coverage/quality
   - `iron-law-judge` — all 34 Iron Laws
   - `verification-runner` — build + test pass?
4. **context-supervisor** compresses to `.claude/reviews/pr-{num}/summary.md`
5. Compose final PR comment with severity-grouped findings

## Iron Laws

- All 34 apply
- No "LGTM" without actually reading the diff
- Every finding cites `file:line` — no unsourced nits
- Don't approve if `verification-runner` reports broken build/tests

## Severity Rubric

- 🔴 Must-fix (blocking) — Iron Law violation, security, data loss,
  broken build
- 🟠 Should-fix — bug risk, N+1, missing tests, unclear naming
- 🟡 Nit — style, minor refactor, comment cleanup
- 🟢 Praise — acknowledge good patterns (balances the review)

## Output

```markdown
## PR Review: #1234 — <title>

**Verdict**: 🛑 Changes requested / ✅ Approved / 💬 Comment

### 🔴 Must-fix (2)

1. **Missing `[Authorize]` on new endpoint**
   `src/Api/Orders/OrdersController.cs:87`
   ```csharp
   [HttpDelete("{id:long}")]
   public Task<IActionResult> Delete(long id) // ← no [Authorize]
   ```

   Iron Law #13. Add `[Authorize(Policy = "OrderOwner")]`.

### 🟠 Should-fix (3)

...

### 🟡 Nits (5)

...

### 🟢 Praise

- Clean use of `IAsyncEnumerable<T>` in `StreamAsync` — good choice
  over `Task<List<T>>` for large result sets

```

## Post Back

Confirm with user before posting:

```bash
gh pr review <num> --request-changes --body "$(cat review.md)"
# or
gh pr review <num> --approve --body "..."
```

## Integration

```
/dotnet:pr-review 1234 → .claude/reviews/pr-1234/summary.md
        ↓
user confirms → gh pr review 1234 --request-changes
```

## References

- `${CLAUDE_SKILL_DIR}/references/review-voice.md` — constructive
  tone, avoid nitpicking fatigue
- `${CLAUDE_SKILL_DIR}/references/gh-cli-patterns.md` — fetching diff,
  inline vs general comments, approvals
- `${CLAUDE_SKILL_DIR}/references/severity-calibration.md` — when to
  block vs comment

## Anti-patterns

- Posting a wall of 🟡 nits — reviewer fatigue, loses signal
- Missing the Critical because the reviewer over-focused on style
- No `verification-runner` result — approving a broken build
- Posting review without user confirmation — this is irreversible
  noise
