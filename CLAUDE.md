# Plugin Development Guide

Development documentation for the .NET AI Toolkit Claude Code plugin.

## Overview

This plugin provides **agentic workflow orchestration** with specialist agents and reference skills for .NET 8+ development — C#, ASP.NET Core (Web API + Minimal API), Entity Framework Core, Blazor (Server/WASM/Hybrid), .NET MAUI, WPF, and xUnit.

## Workflow Architecture

The plugin implements a **Plan → Work → Review → Compound** lifecycle:

```
/dotnet:plan → /dotnet:work → /dotnet:review → /dotnet:compound
      │              │              │                 │
      ↓              ↓              ↓                 ↓
plans/{slug}/   (in namespace)  (in namespace)   solutions/
```

**Key principle**: Filesystem is the state machine. Each phase reads from the previous phase's output. Solutions feed back into future cycles.

### Workflow Commands

| Command | Phase | Input | Output |
|---------|-------|-------|--------|
| `/dotnet:plan` | Planning | Feature description | `plans/{slug}/plan.md` |
| `/dotnet:plan --existing` | Enhancement | Plan file | Enhanced plan with research |
| `/dotnet:brief` | Understanding | Plan file | Interactive walkthrough (ephemeral) |
| `/dotnet:work` | Execution | Plan file | Updated checkboxes, `plans/{slug}/progress.md` |
| `/dotnet:review` | Quality | Changed files | `plans/{slug}/reviews/` |
| `/dotnet:compound` | Knowledge | Solved problem | `solutions/{category}/{fix}.md` |
| `/dotnet:full` | All | Feature description | Complete cycle with compounding |

### Artifact Directories

Each plan owns all its artifacts in a namespace directory:

```
.claude/
├── plans/{slug}/              # Everything for ONE plan
│   ├── plan.md                # The plan itself
│   ├── research/              # Research agent output
│   ├── reviews/               # Review agent output (individual tracks)
│   ├── summaries/             # Context-supervisor compressed output
│   ├── progress.md            # Progress log
│   └── scratchpad.md          # Auto-written decisions, dead-ends, handoffs
├── audit/                     # Audit namespace (not plan-specific)
├── reviews/                   # Fallback for ad-hoc reviews (no plan)
├── scratchpad/                # Session scratch
└── solutions/{category}/      # Global compound knowledge
    ├── ef-issues/
    ├── api-issues/
    ├── blazor-issues/
    └── ...
```

### Context Supervisor Pattern

Orchestrators that spawn multiple sub-agents use a generic `context-supervisor` (haiku) to compress worker output before synthesis. This prevents context exhaustion in the parent:

```
Orchestrator (thin coordinator)
  └─► context-supervisor reads N worker output files
      └─► writes summaries/consolidated.md
          └─► Orchestrator reads only the summary
```

Used by: `planning-orchestrator`, `parallel-reviewer`, `audit` skill.

## Structure

```
dotnet-ai-toolkit/
├── .claude-plugin/
│   └── marketplace.json
├── scripts/
│   ├── fetch-claude-docs.sh
│   └── fetch-cc-changelog.sh
├── lab/
│   ├── eval/                       # 8-dimension skill + 5-dimension agent scoring
│   └── autoresearch/               # Auto-improvement loop
└── plugins/
    └── dotnet/
        ├── .claude-plugin/plugin.json
        ├── agents/                 # 20 specialist agents
        │   ├── workflow-orchestrator.md
        │   ├── planning-orchestrator.md
        │   ├── context-supervisor.md
        │   └── ...
        ├── hooks/
        │   ├── hooks.json          # Format, Iron Laws, progress, STOP
        │   └── scripts/*.sh        # 19 bash scripts
        └── skills/                 # 40 skills
            ├── plan/
            ├── work/
            ├── review/
            ├── full/
            ├── compound/
            └── ...
```

## Conventions

### Agents

Agents are specialist reviewers/researchers that analyze code without modifying it (reviewers) or write research artifacts (researchers).

**Frontmatter:**

```yaml
---
name: my-agent
description: Description with "Use proactively when..." guidance
tools: Read, Grep, Glob, Bash, Write
disallowedTools: Edit, NotebookEdit
permissionMode: bypassPermissions
model: sonnet
effort: medium
memory: project
skills:
  - relevant-skill
---
```

**Rules:**

- Use `sonnet` by default (Sonnet 4.6 = near-opus quality at lower cost)
- `opus` for primary workflow orchestrators and security-critical agents
- `haiku` for mechanical tasks: compression, verification, web research
- `effort:` matches cognitive load (`low`/`medium`/`high`)
- Review agents are **read-only** (`disallowedTools: Edit, NotebookEdit`) — Write IS allowed so they can save their own findings file
- Use `permissionMode: bypassPermissions` for all agents (default causes "Bash permission check failed" when agents run in background)
- Use `memory: project` for agents benefiting from cross-session learning (orchestrators, pattern analysts). Note: `memory` auto-enables Read/Write/Edit — only add to agents already with Write access
- Preload relevant skills via `skills:` field
- Add `omitClaudeMd: true` for read-only agents (no Edit) — Iron Laws are injected via SubagentStart hook
- Keep under 300 lines

### Skills

Skills provide domain knowledge with progressive disclosure.

**Structure:**

```
skills/{name}/
├── SKILL.md           # ~100 lines max
└── references/        # Detailed content
    └── *.md
```

**Rules:**

- SKILL.md: ~100 lines max (~500 tokens). Command skills may reach ~185
- Include an "Iron Laws" section for critical rules
- Move detailed patterns to `references/`
- Set `effort:` to match complexity: `low` for mechanical (verify, quick, compound), `medium` for reference skills, `high` for complex reasoning (plan, full, investigate, review)
- Use `${CLAUDE_SKILL_DIR}/references/` for reference file paths (not bare `references/`)
- No `triggers:` field — rely on `description` for auto-loading
- **Description must be under 250 characters** — Claude Code internally caps skill listing entries. Longer descriptions are silently truncated. Target ≤200 chars

### Workflow Skills

Workflow skills (`plan`, `work`, `review`, `compound`, `full`) have special structure:

- Define clear input/output artifacts
- Reference other workflow phases
- Include integration diagram showing position in cycle
- Document state transitions

### Compound Knowledge Skills

The compound system captures solved problems as searchable institutional knowledge:

- `compound-docs` — Schema and reference for solution documentation
- `compound` (`/dotnet:compound`) — Post-fix knowledge capture skill

Solution docs use YAML frontmatter (see `compound-docs/references/schema.md`).

### Hooks

Defined in `hooks/hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": [...],            // Block dangerous ops (ef database drop, force push, rm -rf bin/obj)
    "PostToolUse": [...],           // Format + Iron Law verify + security + progress + plan STOP + debug stmt + vuln scan
    "PostToolUseFailure": [...],    // .NET failure hints + error critic for dotnet commands
    "SubagentStart": [...],         // Iron Laws injection into all subagents
    "SessionStart": [...],          // Setup dirs + resume detection + branch freshness
    "PreCompact": [...],            // Re-inject workflow rules before compaction
    "PostCompact": [...],           // Verify plan state survived compaction
    "StopFailure": [...],           // Log API failures to scratchpad for resume
    "Stop": [...]                   // Warn if uncompleted tasks
  }
}
```

**Current hooks:**

- `PreToolUse` (Bash): Block destructive operations (`dotnet ef database drop`, `git push --force`, `rm -rf bin obj`) before execution
- `PostToolUse` (Edit): Auto `dotnet format`, **programmatic Iron Law verification**, **debug statement detection** — all use `if` filters (e.g., `"if": "Edit(*.cs)"`) to avoid spawning shells on non-.NET files
- `PostToolUse` (Write): Same .NET checks as Edit + plan STOP reminder (`"if": "Write(*plan.md)"`) + NuGet vulnerability scan (`"if": "Write(*.csproj)"`, async) + secret scan in `appsettings*.json`
- `PostToolUse` (Edit|Write): Security Iron Laws on auth files, async progress logging
- `PostToolUseFailure` (Bash): `.NET`-specific hints + **error critic** (both `"if": "Bash(*dotnet*)"`)
- `SubagentStart`: Inject all 34 Iron Laws via `hookSpecificOutput.additionalContext`
- `PreCompact`: Re-inject workflow rules via JSON `systemMessage`
- `SessionStart` (all): Setup `.claude/` dirs
- `SessionStart` (startup|resume): Scratchpad check + resume detection + branch freshness (async) + startup message
- `PostCompact`: Verify active plan state survived compaction
- `StopFailure`: Log API failure to scratchpad for next-session resume detection
- `Stop`: Warn if plans have unchecked tasks

**Hook output patterns:**

- `PostToolUse` stdout is verbose-mode-only — use `exit 2` + stderr to feed messages to Claude
- `PreCompact` has no stdout context injection — use JSON `systemMessage`
- `SessionStart` stdout IS added to Claude's context (one of two exceptions along with `UserPromptSubmit`)
- `SubagentStart` uses `hookSpecificOutput.additionalContext` to inject context into subagents
- `PostToolUseFailure` uses `hookSpecificOutput.additionalContext` for debugging hints
- `PostCompact` uses `exit 2` + stderr to warn Claude
- `StopFailure` uses `exit 2` + stderr and writes to scratchpad file

## Development

### Testing locally

```bash
# Option A: Test plugin directly
claude --plugin-dir ./plugins/dotnet

# Option B: Add as local marketplace
/plugin marketplace add .
/plugin install dotnet
```

When editing skills/agents/hooks mid-session, run `/reload-plugins` to pick up changes without restarting Claude Code (v2.1.98+).

### Adding a new agent

1. Create `plugins/dotnet/agents/{name}.md`
2. Add frontmatter with all required fields
3. Keep under 300 lines

### Adding a new skill

1. Create `plugins/dotnet/skills/{name}/SKILL.md` (~100 lines)
2. Create `references/` with detailed content
3. For workflow skills, document integration with cycle

### Setup

```bash
npm install   # Pre-commit hooks + linting
pip install -r requirements.txt   # Eval framework deps
```

### Quality Commands (use `make`)

```bash
make help          # Show all commands
make lint          # Lint markdown
make lint-fix      # Auto-fix lint
make test          # Pytest suite for eval framework
make eval          # Quick: lint + score changed skills/agents only
make eval-all      # Score all 40 skills + 20 agents
make eval-fix      # Auto-fix lint + show failures + suggest autoresearch
make ci            # Full CI pipeline: lint + test + validate + eval
```

### Eval Framework (lab/eval/)

Deterministic 8-dimension scoring for skills and 5-dimension scoring for agents. **Run `make eval` after every skill/agent edit.**

**When editing skills/agents, ALWAYS verify your changes pass eval:**

1. Edit the skill or agent file
2. Run `make eval` — checks only changed files
3. If FAIL: run `make eval-fix` to see exact failures and fix suggestions
4. Fix the issues and re-run until PASS

**What eval checks** (skills — 8 dimensions):

- completeness (sections, Iron Laws, frontmatter)
- accuracy (cross-references valid)
- conciseness (line counts, section limits)
- triggering (description keywords, "Use when..." structure)
- safety (Iron Laws, prohibitions, no dangerous patterns)
- clarity (action density, no duplication, step coverage)
- specificity (code examples, concrete vs vague)
- behavioral (trigger accuracy via cached haiku tests)

**What eval checks** (agents — 5 dimensions):

- completeness (frontmatter: name, description, tools, model, effort)
- accuracy (preloaded skills exist, tools valid)
- conciseness (line limits per agent type)
- safety (bypassPermissions, read-only enforcement)
- consistency (model matches effort level)

## Size Guidelines

| Component | Target | Hard Limit | Notes |
|-----------|--------|------------|-------|
| SKILL.md (reference) | ~100 | ~150 | Iron Laws + quick patterns |
| SKILL.md (command) | ~100 | ~185 | Command skills need complete execution flow inline |
| references/*.md | ~350 | ~350 | Detailed patterns |
| agents (specialist) | ~300 | ~365 | Design guidance beyond preloaded skill patterns |
| agents (orchestrator) | ~300 | ~535 | Subagent prompts + flow control must be inline |

### Why orchestrators and command skills exceed targets

Plugin files live in `~/.claude/plugins/cache/` — outside the project. This means agents **cannot reliably read** skill `references/*.md` at runtime (permission prompts).

Content must be inline (in agent prompt or preloaded SKILL.md) to be available:

| Location | Auto-available? | Reliable? |
|----------|----------------|-----------|
| Agent system prompt | Yes | Yes |
| Preloaded skill SKILL.md (`skills:` field) | Yes | Yes |
| Skill `references/*.md` | No — needs Read call | No — permission prompt |

## Checklist

### New agent

- [ ] Frontmatter complete
- [ ] `disallowedTools: Edit, NotebookEdit` for review agents (Write IS allowed so they can save findings)
- [ ] `permissionMode: bypassPermissions`
- [ ] `effort:` set (low for haiku, medium for sonnet, high for opus/security)
- [ ] `omitClaudeMd: true` for report-only agents
- [ ] Skills preloaded
- [ ] Description under 250 characters
- [ ] Under target (300 lines)

### New skill

- [ ] SKILL.md under target (~100 lines), hard limit for command skills (~185)
- [ ] "Iron Laws" section
- [ ] `references/` paths use `${CLAUDE_SKILL_DIR}/references/`
- [ ] `effort:` set
- [ ] No `triggers:` field
- [ ] Description under 250 characters

### Release

- [ ] All markdown passes linting
- [ ] Version bumped in `plugins/dotnet/.claude-plugin/plugin.json`
- [ ] `CHANGELOG.md` updated
- [ ] README updated
- [ ] `/dotnet:intro` tutorial still accurate

### Versioning

- **MAJOR**: Breaking changes (workflow redesign, removed commands)
- **MINOR**: New features (new hooks, skills, agents)
- **PATCH**: Bug fixes, doc updates

Users only receive updates when the version in `plugin.json` changes.

---

# Claude Code Behavioral Instructions

**CRITICAL**: These instructions OVERRIDE default behavior for .NET projects in this codebase.

## Automatic Skill Loading

When working on .NET code, ALWAYS load relevant skills based on file context:

| File Pattern | Auto-Load Skills | Check References |
|--------------|------------------|------------------|
| `*Controller.cs`, `Program.cs` with `MapGet`/`MapPost` | `api-design` | `references/minimal-apis.md`, `references/controllers.md` |
| `*DbContext.cs`, `Migrations/*.cs`, `*Configuration.cs` | `ef-patterns` | `references/queries.md`, `references/migrations.md` |
| `*.razor`, `*.razor.cs`, `App.razor`, `Routes.razor` | `blazor-patterns` | `references/render-modes.md`, `references/state-management.md` |
| `*Page.xaml.cs`, `AppShell.xaml.cs`, `MauiProgram.cs` | `maui-patterns` | `references/mvvm.md`, `references/platform-services.md` |
| `*.xaml`, `*Window.xaml.cs` (non-MAUI) | `wpf-patterns` | `references/mvvm.md`, `references/data-binding.md` |
| `*Tests.cs`, `*Test.cs`, `*.Tests/*.cs` | `testing` | `references/xunit-patterns.md`, `references/moq-nsubstitute.md` |
| `Program.cs`, `Startup.cs`, `*ServiceCollection*.cs` | `di-patterns` | `references/lifetimes.md`, `references/options.md` |
| `*Auth*.cs`, `JwtBearer*.cs`, `*Policy*.cs` | `security` | `references/authentication.md`, `references/authorization.md` |
| `Dockerfile`, `*.Dockerfile`, `appsettings*.json`, `.k8s/*.yml` | `deploy` | `references/docker.md`, `references/config.md` |
| Any `.cs` file | (check all Iron Laws) | Always |

### Skill Loading Behavior

1. When opening/editing a file matching patterns above, silently load the skill
2. Apply Iron Laws from loaded skills as validation rules
3. If code violates an Iron Law, **stop and explain** before proceeding
4. Reference detailed docs from `references/` when making implementation decisions

## Workflow Routing (Proactive)

When the user's FIRST message describes work without specifying a `/dotnet:` command:

1. Detect intent (see `intent-detection` skill for routing table)
2. If multi-step workflow detected, suggest the appropriate command
3. Format: "This looks like [intent]. Want me to run `/dotnet:[command]`, or should I handle it directly?"
4. For trivial tasks: skip suggestion, just do it
5. Never block the user — suggestion only, one attempt max

### Debugging Loop Detection

The `error-critic.sh` hook automatically detects repeated `dotnet` failures and escalates from generic hints (attempt 1) to structured critic analysis (attempt 3+). Implements the Critic→Refiner pattern: structured error consolidation before retry prevents debugging loops.

If the hook hasn't triggered, when 3+ consecutive `dotnet build`/`dotnet test` commands fail, suggest: "Looks like a debugging loop. Want me to run `/dotnet:investigate` for structured analysis?"

### Sibling File Check

When fixing a bug in a file that has named variants (e.g., `BuyerController.cs`, `SellerController.cs`, `AdminController.cs`), proactively grep for siblings and check if the same bug exists in each variant. Do this BEFORE implementing the fix, not after.

### Scoped Format and Build Checks

When running `dotnet format --verify-no-changes` or `dotnet build`, **always scope to the files/project you changed** when possible. If a full-solution check fails on files you didn't edit, report it as pre-existing and continue.

## Iron Laws Enforcement (NON-NEGOTIABLE)

These 34 rules are NEVER violated. If code would violate them, **STOP and explain** before proceeding.

### C# Core Iron Laws

1. **NEVER use `float`/`double` for money** — use `decimal`. Float is base-2; rounding errors accumulate in financial calcs
2. **NEVER call `.Result` or `.Wait()` on a `Task`** — always `await`. Sync-over-async deadlocks in UI/ASP.NET synchronization contexts
3. **WRAP `IDisposable` in `using`** — leak connections, file handles, timers otherwise. `await using` for `IAsyncDisposable`
4. **PROPAGATE `CancellationToken`** through all async methods that do I/O — no `CancellationToken.None` swallowing
5. **HONOR nullable annotations** — don't `!` away `string?` without verifying. Nullable warnings are correctness signals

### EF Core Iron Laws

6. **USE `AsNoTracking()` for read-only queries** — otherwise Change Tracker holds all entities for the DbContext lifetime
7. **PARAMETERIZE all SQL** — never `FromSqlRaw($"... {userInput}")` interpolation. Use `FromSqlInterpolated` or parameters
8. **ONE `SaveChangesAsync` per Unit of Work** — not in a loop. Batch all mutations, call once
9. **`.Include(...)` BEFORE `.Where(...)` when eager-loading** — Where after Include on the navigation filters the loaded collection, which is usually wrong
10. **INDEX all foreign keys** — EF Core 7+ does this by convention; verify in `OnModelCreating` or migrations
11. **NO N+1 queries** — use `.Include` / `.ThenInclude` / `.AsSplitQuery`. Projecting a list and then iterating `.ForEach(x => ctx.Other.Where(...))` is N+1
12. **SET `HasPrecision(18, 2)` on decimal properties in `OnModelCreating`** — default maps to SQL `decimal(18,2)` only for SQL Server; other providers differ

### ASP.NET Core Iron Laws

13. **`[Authorize]` on ALL non-public endpoints** — default to secure. Use `[AllowAnonymous]` to opt out explicitly
14. **NEVER accept/return EF entities at the API boundary** — use DTOs. Over-posting and cyclic-serialization bugs
15. **VALIDATE at the boundary** — `[ApiController]` for auto-ModelState or FluentValidation. Never trust client input
16. **RATE LIMIT auth endpoints** — `builder.Services.AddRateLimiter(...)`. Login/register/reset flows need throttling
17. **RESTRICT CORS** — `AllowAnyOrigin()` is a security hole. Allowlist domains explicitly
18. **RETURN `ProblemDetails` on errors** — via exception middleware. Leaking stack traces in prod = information disclosure

### Blazor Iron Laws

19. **`StateHasChanged` from non-UI thread needs `InvokeAsync(StateHasChanged)`** — otherwise threading exception
20. **USE `@key` for dynamic lists** — without it, Blazor reuses DOM nodes incorrectly on reorder/insert/delete
21. **NEVER store secrets in Blazor WASM** — all code ships to the browser. Use the server's API for secret-gated operations
22. **DISPOSE subscriptions + timers in `IDisposable.Dispose`** — component lifetime ≠ process lifetime; leaks accumulate

### MAUI/WPF Iron Laws

23. **MVVM: no logic in code-behind** — ViewModels own state and commands. Code-behind is for view-only wiring
24. **USE `ObservableCollection<T>` for bindable lists** — regular `List<T>` doesn't notify the UI on changes
25. **WEAK EVENT patterns for long-lived publishers** — `WeakReferenceMessenger` (CommunityToolkit) or `WeakEventManager`. Otherwise the publisher keeps subscribers alive

### Security Iron Laws

26. **NEVER `string.Format`/interpolate SQL** — always parameters. Applies to Dapper, ADO.NET, EF's raw SQL
27. **HASH passwords via `PasswordHasher<T>`** (Identity) or `Rfc2898DeriveBytes` with 100k+ iterations — never MD5/SHA1/plain SHA256
28. **SECRETS via User Secrets / Key Vault / environment variables** — never in `appsettings.json` committed to git
29. **JWT validation MUST check issuer, audience, lifetime, and signing key** — defaults in `TokenValidationParameters` are permissive. Explicit is required
30. **ANTI-FORGERY tokens on all state-changing form submissions** — enabled by default for Razor Pages/MVC, must be opted-into for APIs that accept cookies

### DI Iron Laws

31. **`DbContext` = `Scoped`** — never `Singleton` (concurrency corruption) or `Transient` (change-tracker chaos)
32. **HTTPClient via `IHttpClientFactory`** — direct `new HttpClient()` = socket exhaustion under load
33. **USE `IOptions<T>` / `IOptionsSnapshot<T>` / `IOptionsMonitor<T>`** — not raw `IConfiguration` reads in hot paths. Options are validated once at startup

### Verification Iron Law

34. **VERIFY BEFORE CLAIMING DONE** — Never say "should work" or "this fixes it." Run `dotnet build && dotnet test` and show the result. If you can't verify, explicitly state what remains unverified

### Violation Response

When detecting a potential Iron Law violation:

```
STOP: This code would violate Iron Law [number]: [description]

What you wrote:
[problematic code]

Correct pattern:
[fixed code]

Should I apply this fix?
```

## Framework Detection

### .NET Version Detection

Check `global.json`, `Directory.Build.props`, or any `.csproj` for `<TargetFramework>`:

- `net8.0` / `net9.0` / `net10.0` / `net11.0`: all modern patterns apply (primary constructors, collection expressions, `required` members, Minimal APIs, Blazor United)
- `net7.0`: skip primary-constructor suggestions on non-record types; rate limiting middleware API differs
- `net6.0` or earlier: Minimal APIs exist but fewer route-group features. Flag as EOL-soon for security reviews

### Framework Detection (per project type)

| Marker | Project type | Skill bias |
|--------|--------------|------------|
| `Microsoft.AspNetCore.App` in .csproj | ASP.NET Core | `api-design` |
| `Microsoft.NET.Sdk.Web` + `*.razor` | Blazor | `blazor-patterns` |
| `Microsoft.NET.Sdk.Maui` | MAUI | `maui-patterns` |
| `UseWPF=true` | WPF | `wpf-patterns` |
| `Microsoft.EntityFrameworkCore.*` packages | EF Core | `ef-patterns` |
| `xunit`, `NUnit`, `MSTest.TestFramework` | Test project | `testing` |

## Greenfield Project Detection

If project has <10 `.cs` files (new project):

1. **Use simpler planning** (no parallel agents needed)
2. **Suggest initial setup**: `.editorconfig`, analyzers (`Microsoft.CodeAnalysis.NetAnalyzers`), test project scaffold

## Reference Auto-Loading

| Code Pattern | Skill | References to Consult |
|--------------|-------|----------------------|
| `[HttpGet]` / `[HttpPost]` / `app.MapGet` | api-design | minimal-apis.md, controllers.md, validation.md |
| `Microsoft.EntityFrameworkCore` using | ef-patterns | queries.md, changesets.md |
| `HasMany` / `HasOne` in `OnModelCreating` | ef-patterns | relationships.md |
| `modelBuilder.Entity<T>().HasIndex(...)` | ef-patterns | migrations.md |
| `DbContext` registration | di-patterns | lifetimes.md |
| `@page`, `@rendermode` | blazor-patterns | render-modes.md |
| `InvokeAsync(StateHasChanged)` | blazor-patterns | state-management.md |
| `ContentPage`, `Shell`, `RelativeBindingSource` | maui-patterns | mvvm.md, navigation.md |
| `DependencyProperty` | wpf-patterns | data-binding.md |
| `xUnit` attributes (`[Fact]`, `[Theory]`) | testing | xunit-patterns.md |
| `WebApplicationFactory` | testing | integration-tests.md |
| `AddAuthentication().AddJwtBearer(...)` | security | authentication.md |
| `RequireAuthorization` / `[Authorize(Policy)]` | security | authorization.md |
| `UserSecrets` / `KeyVault` references | security | secrets.md |
| `app.UseExceptionHandler` / `IProblemDetailsService` | api-design | middleware.md |
| `BenchmarkDotNet` usage | perf | bench-patterns.md |

### Consultation Behavior

1. **Before implementing**, read relevant reference for correct pattern
2. **Silently apply** patterns (don't narrate unless complex)
3. **Check Iron Laws** from skill before and after implementation
4. **Security code ALWAYS gets reference consultation** (authentication.md, authorization.md)

## Command Suggestions

| User Intent | Command |
|-------------|---------|
| "Which command should I use?" | `/dotnet:help` |
| New to the plugin | `/dotnet:intro` |
| Bug fix, debug | `/dotnet:investigate` |
| Small UI fix, CSS tweak, config change | `/dotnet:quick` |
| Small change (<50 lines) | `/dotnet:quick` |
| Brainstorm, explore ideas, unclear scope | `/dotnet:brainstorm` |
| New feature (clear scope) | `/dotnet:plan` then `/dotnet:work` |
| Understand a plan | `/dotnet:brief` |
| Enhance existing plan | `/dotnet:plan --existing` |
| Large feature (new domain) | `/dotnet:full` |
| Review code | `/dotnet:review` |
| Triage review findings | `/dotnet:triage` |
| Capture solved problem | `/dotnet:compound` |
| Run checks | `/dotnet:verify` |
| Research topic | `/dotnet:research` |
| Evaluate a NuGet package | `/dotnet:research --library` |
| Resume work | `/dotnet:work --continue` |
| N+1 query check | `/dotnet:n-plus-one-check` |
| EF migration safety | `/dotnet:migration-check` |
| PR review comments | `/dotnet:pr-review` |
| Performance analysis | `/dotnet:perf` |
| Project health | `/dotnet:audit` |
| Reduce permission prompts | `/dotnet:permissions` |

**Workflow Commands**: `/dotnet:brainstorm` (optional) → `/dotnet:plan` → `/dotnet:brief` (optional) → `/dotnet:plan --existing` (optional) → `/dotnet:work` → `/dotnet:review` → `/dotnet:triage` (optional) → `/dotnet:compound`

**Standalone**: `/dotnet:quick`, `/dotnet:full`, `/dotnet:investigate`, `/dotnet:verify`, `/dotnet:research`, `/dotnet:brainstorm`, `/dotnet:help`, `/dotnet:permissions`

**Analysis**: `/dotnet:n-plus-one-check`, `/dotnet:migration-check`, `/dotnet:boundaries`, `/dotnet:techdebt`, `/dotnet:perf`, `/dotnet:audit`

## Workflow Patterns

### Challenge Mode

When I say "grill me" or "challenge this":

- Review changes as a senior .NET engineer would
- Check for: N+1 queries, missing `ConfigureAwait`, async-over-sync anti-patterns, missing `[Authorize]`, DI lifetime bugs, disposal leaks, missing cancellation-token propagation, over-posting, improper exception handling
- Diff behavior between `main` and current branch
- Don't approve until issues are addressed

### Elegance Reset

When I say "make it elegant" or "knowing everything you know now":

- Scrap the current approach
- Implement the idiomatic C# solution
- Prefer LINQ/`switch` expressions over imperative loops
- Prefer records + pattern matching over DTO boilerplate
- Prefer `async`/`await` + `IAsyncEnumerable` over manual threading
- Use dependency injection + options pattern where applicable

### Auto-Fix Patterns

When I say:

- "fix CI" → Run `dotnet build && dotnet test` and fix all failures
- "fix it" → Look at error/bug context and autonomously fix without asking
- "fix format" → Run `dotnet format` on changed files
- "fix analyzers" → Run `dotnet build /warnaserror` and fix all analyzer warnings

### Learn From Mistakes

After ANY correction I make:

- Ask: "Should I update CLAUDE.md so this doesn't happen again?"
- If yes, add a concise rule preventing the specific mistake
- Keep rules actionable: "Do NOT X — instead Y"

### Intro Tutorial Maintenance

When adding/removing/renaming commands/skills/agents, check if `plugins/dotnet/skills/intro/references/tutorial-content.md` needs updating. Stale command references erode trust with new users.

### Interesting Findings Log

When you discover something noteworthy during work — a surprising metric, a counter-intuitive finding, a useful pattern from research — **append it to `lab/findings/interesting.jsonl`** immediately. Gitignored; feeds release notes and social posts.
