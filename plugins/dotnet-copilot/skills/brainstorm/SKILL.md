---
name: brainstorm
description: Exploratory design discussion — generate and pressure-test architectural options for .NET problems before committing to a plan. Use when scope is unclear or multiple approaches exist.
argument-hint: <topic or problem>
effort: medium
---

# brainstorm

Interactive design exploration. Produces **options**, not a plan. Use
before `/dotnet:plan` when the problem space is ambiguous.

## When to Use

- You have a goal but no clear approach ("how should we version the
  API?", "should this be Blazor Server or WASM?")
- Trade-offs are non-obvious (sync vs event-driven, EF vs Dapper,
  Minimal API vs Controllers)
- You want to explore 2–4 alternatives with pros/cons

Use `/dotnet:plan` once you've picked a direction.

## Flow

1. Clarify the goal and constraints in one round of Q&A
2. Enumerate **2–4 options** with concrete .NET implementations
3. For each option: pros, cons, Iron Law alignment, complexity estimate
4. Recommend one (or say "depends on X") with justification
5. If user picks one, suggest `/dotnet:plan "implement option N"`

## Option Shape

Each option is:

```markdown
### Option N: <name>

**Approach**: one-paragraph description referencing actual .NET
primitives (not vague architecture words)

**Implementation sketch**:
```csharp
// 5-15 lines showing the key call sites
```

**Pros**:

- ...
- ...

**Cons**:

- ...
- ...

**Iron Law considerations**: any that are relevant

**Complexity**: S / M / L

```

## Example Topics

- "Authentication: cookie vs JWT vs both?"
- "Background work: Hangfire vs Quartz vs hosted BackgroundService?"
- "Real-time: SignalR vs SSE vs polling?"
- "Multi-tenancy: schema-per-tenant vs row-level vs separate DBs?"
- "Migration strategy: big-bang vs strangler vs parallel run?"

## Iron Laws

Options that would violate Iron Laws are flagged, not silently
discarded — sometimes the violation is an explicit trade-off the user
accepts. But the flag must be visible.

## Output

Inline Markdown; no file written. If the user says "let's do option
3", hand off to `/dotnet:plan`.

## Integration

```

/dotnet:brainstorm → pick direction → /dotnet:plan → /dotnet:work

```

## References

- `${CLAUDE_SKILL_DIR}/references/design-heuristics.md` — when to
  prefer simple vs configurable, YAGNI vs future-proofing
- `${CLAUDE_SKILL_DIR}/references/tradeoff-matrix.md` — common .NET
  trade-offs (performance vs maintainability, etc.)
- `${CLAUDE_SKILL_DIR}/references/stack-choices.md` — common
  library/pattern decisions with opinionated defaults

## Anti-patterns

- Single option disguised as "brainstorm" — defeats the purpose
- 10 options with no recommendation — decision fatigue
- Pure abstractions without concrete .NET primitives — users cannot
  evaluate
- Brainstorming trivial problems where the answer is obvious
