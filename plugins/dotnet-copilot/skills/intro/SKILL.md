---
name: intro
description: Guided tour of the .NET AI Toolkit — commands, agents, Iron Laws, workflow. Use if new to the plugin or teaching a collaborator.
effort: low
---

# /dotnet:intro

Interactive walkthrough of the plugin's moving parts. Chat-only.

## Outline

1. **Welcome** — what the plugin does (agentic workflow orchestration for
   .NET)
2. **Core loop** — `/dotnet:plan` → `/dotnet:work` → `/dotnet:review` →
   `/dotnet:compound`
3. **Or the shortcut** — `/dotnet:full` for autonomous delivery
4. **Iron Laws** — 34 non-negotiable rules
5. **Specialist agents** — 20 of them, each focused
6. **Hooks** — what runs in the background (format, Iron Law check,
   vulnerability scan, STOP reminders)
7. **Artifacts** — `.claude/plans/`, `.claude/solutions/`
8. **Cheat sheet** — command by intent

## Flow

1. Ask user: "New here? Or want a refresher on something specific?"
   - New → full tour
   - Specific → jump to that section
2. Tour is 5–7 short messages, each ~80 words, with one concrete example
3. End with "Try it: describe your feature / paste a bug / ask a question"

## Segments (each ~80 words)

### Segment 1 — Lifecycle

```
The plugin is built around four phases:

1. PLAN — /dotnet:plan decomposes a feature with research agents, writes
   .claude/plans/{slug}/plan.md
2. WORK — /dotnet:work executes task-by-task, routing each to specialists
   (e.g., [ef] tasks consult ef-schema-designer)
3. REVIEW — /dotnet:review spawns 5 reviewers in parallel (code, tests,
   security, Iron Laws, verification)
4. COMPOUND — /dotnet:compound captures solved problems as durable knowledge

Or use /dotnet:full for the whole cycle autonomously.
```

### Segment 2 — Iron Laws

```
34 non-negotiable rules are always active. Examples:

- #1: decimal (not float) for money
- #2: never .Result / .Wait on Tasks
- #6: AsNoTracking on read queries
- #13: [Authorize] on all non-public endpoints
- #28: secrets in User Secrets / Key Vault, never appsettings.json

Violations block code changes. iron-law-verifier.sh hook scans every edit.
The full list is in CLAUDE.md.
```

### Segment 3 — Specialists

```
20 specialists cover the surface area:

- Reviewers: dotnet-reviewer, testing-reviewer, security-analyzer,
  iron-law-judge, verification-runner
- Architects: api-architect, ef-schema-designer, blazor-architect,
  maui-specialist, wpf-specialist
- Advisors: di-advisor, performance-profiler, deployment-validator
- Investigators: deep-bug-investigator, nuget-researcher, web-researcher
- Orchestrators: workflow, planning, parallel-reviewer, context-supervisor

You rarely call them directly — skills do.
```

### Segment 4 — Hooks

```
Silent background hooks catch issues as you edit:

- format-dotnet.sh: auto-format on save
- iron-law-verifier.sh: grep for Iron Law violations
- block-secrets-in-config.sh: reject plaintext secrets in appsettings
- check-vulnerable-packages.sh: scan .csproj edits
- block-dangerous-ops.sh: prevent `ef database drop`, `git push --force`
- error-critic.sh: structured analysis after repeat dotnet failures

Visible via hook output when something fires.
```

### Segment 5 — Try it

```
Pick one:

1. "I want to add X" → describe; the plugin will route
2. "Tell me about Iron Law #N" → I'll explain
3. "Show a sample plan" → /dotnet:examples
4. "Set up my repo" → /dotnet:init
5. "What command do I use for Y?" → /dotnet:help
```

## References

- `${CLAUDE_SKILL_DIR}/references/tutorial-content.md` — full tutorial
  text maintained as commands/skills/agents change
- `${CLAUDE_SKILL_DIR}/references/command-index.md` — comprehensive
  command reference

## Maintenance

When adding/removing/renaming commands/skills/agents, update
`references/tutorial-content.md`. Stale intro content erodes first-user
trust.
