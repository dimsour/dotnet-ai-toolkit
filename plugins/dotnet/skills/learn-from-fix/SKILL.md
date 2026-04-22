---
name: dotnet:learn-from-fix
description: Extract durable lessons from a just-finished fix — propose CLAUDE.md rule, Iron Law addition, or Solution doc. Use after resolving a surprising/repeatable bug.
argument-hint: "<optional: specific fix to learn from>"
effort: low
---

# learn-from-fix

Convert a debugging win into institutional memory. Runs after a fix
lands so the same bug doesn't reappear.

## When to Use

- Just fixed something surprising or non-obvious
- Fix involved a pattern the user would hit again
- Correction of Claude's approach ("don't do X, do Y")
- Discovery of a library/framework gotcha

Skip for trivial fixes (typos, obvious off-by-ones).

## Flow

1. Summarize what broke and why in ≤3 sentences
2. Classify the lesson:
   - **CLAUDE.md rule** — instruction to Claude for future sessions
   - **Iron Law candidate** — universal enough to become rule #35+
   - **Solution doc** — concrete problem → fix pattern worth storing
   - **Skill reference update** — existing pattern file needs a new
     section
3. Draft the artifact (rule text, solution doc, reference diff)
4. Ask user to confirm before writing

## Classification Rubric

| Lesson type | Example |
|-------------|---------|
| CLAUDE.md rule | "Claude should check for sibling files before fixing a bug in a named variant" |
| Iron Law | "Never use `float` for money" (this is how Iron Laws get born) |
| Solution doc | "Adding a NOT NULL column to a large table" → two-phase migration |
| Reference update | "Add EF `.AsSplitQuery()` note when `.Include` count ≥ 3" |

## Iron Law Candidacy Check

Before promoting to Iron Law (#35+), confirm:

- [ ] Applies across ≥3 .NET project types (not blazor-specific)
- [ ] Violation is grep-able (programmatic verifier possible)
- [ ] Non-compliance has concrete consequences (data loss, security,
      perf cliff)
- [ ] Can be stated in ≤2 sentences

If any fail, demote to CLAUDE.md rule or reference update.

## Output

One of:

1. **CLAUDE.md patch** — diff against the behavioral-instructions section
2. **Solution doc** — `.claude/solutions/{category}/{slug}.md` (uses
   `/dotnet:compound` format)
3. **Skill reference update** — diff against
   `plugins/dotnet/skills/<name>/references/*.md`
4. **Iron Law proposal** — drafted rule, with verifier grep pattern,
   submitted to CLAUDE.md + `inject-iron-laws.sh`

## Integration

```
/dotnet:work (bug fixed)
        ↓
/dotnet:learn-from-fix → rule / solution / Iron Law candidate
        ↓
/dotnet:compound (if solution doc type)
```

## References

- `${CLAUDE_SKILL_DIR}/references/iron-law-criteria.md` — full rubric
  with examples of accepted/rejected candidates
- `${CLAUDE_SKILL_DIR}/references/rule-writing.md` — how to write
  CLAUDE.md rules: actionable, negated form ("do NOT X — instead Y")
- `${CLAUDE_SKILL_DIR}/references/solution-vs-rule.md` — decision
  tree for classification

## Anti-patterns

- Promoting every fix to Iron Law — bar is high
- Writing vague rules ("be more careful") — must be actionable
- Writing rules that duplicate existing Iron Laws
- Not including a verifier (grep pattern) for new Iron Laws
