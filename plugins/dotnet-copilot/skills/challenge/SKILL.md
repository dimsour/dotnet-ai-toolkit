---
name: challenge
description: Senior-engineer challenge mode — aggressively question the current approach, hunt for N+1 queries, captive deps, missing auth, sync-over-async, leaks. Use before finalizing significant changes.
argument-hint: "<file|plan|PR to challenge>"
effort: medium
---

# challenge

Invert the usual "be helpful" disposition. Act as a sceptical senior
.NET engineer whose job is to **find the flaw before prod does**.

Trigger phrases: "grill me", "challenge this", "poke holes".

## What to Check (the short list)

1. **N+1 queries**: any `.ToList()` → loop that touches a DbContext
   inside? Any lazy-loading enabled + navigation access in a loop?
2. **Async hygiene**: any `.Result`, `.Wait()`, `.GetAwaiter().GetResult()`?
   Any `async void` not an event handler? Any missing
   `CancellationToken` flow?
3. **DI lifetime bugs**: Singleton capturing Scoped? DbContext anywhere
   but Scoped? `IServiceProvider` injection (service locator)?
4. **Authorization**: any new endpoint without `[Authorize]` or
   `.RequireAuthorization()`? Anonymous fallback policy loose?
5. **Over-posting**: mapping `[FromBody] Entity` instead of a DTO?
6. **Disposal**: every `IDisposable` in a `using`? Every subscription /
   timer torn down in `Dispose`?
7. **Exception masking**: `catch (Exception)` with `return null` /
   swallow? `catch { }`?
8. **Secret leakage**: appsettings.json committed with a real key?
   Logging an object that contains a token?
9. **Decimal vs double**: money as `double`? Tax/percentage math in
   `float`?
10. **Race conditions**: shared mutable Singleton state without a lock?
    EF `DbContext` crossing a Task boundary?
11. **Migration safety**: destructive migration without null-default
    backfill? Column rename without two-phase?

## Iron Laws

All 34 apply — this skill is essentially a human-readable Iron Law scan.

## Flow

1. Scan the target (file, PR, plan, or current working tree)
2. Enumerate concrete concerns tied to specific file:line locations
3. For each concern: severity (🔴 Must-fix / 🟠 Should-fix / 🟡 Nit),
   Iron Law reference if applicable, recommended change
4. End with a blunt verdict — "ship it", "fix first", or "stop and
   redesign"

## Tone

- Terse, direct. No hedging. No "you might want to consider"
- Back every claim with file:line or a code snippet
- Acknowledge correct patterns you see — Iron Law judgments cut both
  ways
- If the code is genuinely good, say so

## Output

Inline report to the user; no artifact written unless requested.

## Integration

```
<after work>
        ↓
/dotnet:challenge → inline findings
        ↓
fix or discuss
        ↓
/dotnet:review → formal review
```

## References

- `${CLAUDE_SKILL_DIR}/references/checklist.md` — exhaustive checklist
  across all domains
- `${CLAUDE_SKILL_DIR}/references/perf-smells.md` — perf red flags
  specific to .NET
- `${CLAUDE_SKILL_DIR}/references/security-smells.md` — OWASP-aligned
  checklist

## Anti-patterns

- Using this skill to rubber-stamp ("looks fine") — its purpose is to
  find problems
- Challenging without reading enough context — false positives burn
  trust
- Accepting a challenge finding without verification — the challenger
  can be wrong
