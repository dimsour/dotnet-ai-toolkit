# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2026-04-18

Initial release. Full agentic-workflow Claude Code plugin for
.NET 8+ development — C#, ASP.NET Core, EF Core, Blazor, MAUI,
WPF, and xUnit.

### Added

#### Workflow

- `/dotnet:plan` — Spawns `planning-orchestrator`; research + task
  decomposition → `.claude/plans/{slug}/plan.md`
- `/dotnet:plan --existing` — Enhance an existing plan with fresh
  research
- `/dotnet:brief` — Interactive walkthrough of a plan before coding
- `/dotnet:work` — Executes plan tasks with annotation-based routing
  (`[ef]`, `[api]`, `[test]`, `[security]`, `[direct]`)
- `/dotnet:review` — 5-track parallel review via `parallel-reviewer`
- `/dotnet:triage` — Prioritize review findings into actionable tasks
- `/dotnet:compound` — Capture solved bugs to
  `.claude/solutions/{category}/`
- `/dotnet:full` — End-to-end autonomous plan → work → review →
  compound
- `/dotnet:quick` — Trivial-change fast path (≤50 lines)
- `/dotnet:verify` — `dotnet build`, `dotnet test`, `dotnet format
  --verify-no-changes`

#### Analysis

- `/dotnet:investigate` — Deep-bug-investigator with 4 parallel
  sub-subagents (reproduction, root cause, impact, fix strategy)
- `/dotnet:challenge` — Aggressive senior-engineer review mode
- `/dotnet:brainstorm` — Design option exploration (2–4 options,
  trade-offs)
- `/dotnet:audit` — Full project health audit (5 specialists in
  parallel)
- `/dotnet:boundaries` — Namespace / project-reference boundary
  analysis
- `/dotnet:techdebt` — Ranked tech-debt backlog
- `/dotnet:perf` — Performance hypothesis analysis
- `/dotnet:n-plus-one-check` — EF N+1 query scan with fix suggestions
- `/dotnet:migration-check` — Migration safety validation
- `/dotnet:pr-review` — Multi-track GitHub PR review
- `/dotnet:research` — External documentation / NuGet library research

#### Utility

- `/dotnet:init` — Setup `.claude/` directories
- `/dotnet:intro` — Interactive tutorial
- `/dotnet:help` — Command index
- `/dotnet:permissions` — Configure Claude Code allow/deny lists
- `/dotnet:document` — Generate XML doc comments / README / OpenAPI
  descriptions
- `/dotnet:learn-from-fix` — Extract Iron Law / CLAUDE.md rule
  candidates
- `/dotnet:examples` — Curated .NET reference projects
- `/dotnet:compound-docs` — Schema for compound solution docs
  (internal)

#### Specialist Agents (20)

**Orchestrators (4, opus)**

- `workflow-orchestrator` — End-to-end lifecycle coordination
- `planning-orchestrator` — 6-phase planning flow with Decision Council
- `parallel-reviewer` — Dispatches 5 reviewers in parallel
- `context-supervisor` (haiku) — Compresses worker output before
  synthesis

**Reviewers (4, sonnet unless noted)**

- `dotnet-reviewer` — C# idioms, async, LINQ, DI
- `testing-reviewer` — xUnit, mocking, coverage, isolation
- `security-analyzer` (opus) — OWASP, JWT, secrets, injection
- `iron-law-judge` — All 34 Iron Laws with grep patterns

**Architects + Specialists (10)**

- `ef-schema-designer` — DbContext, migrations, relationships, queries
- `api-architect` — Minimal API + Controllers, validation, versioning
- `blazor-architect` — Render modes, state, forms, streaming SSR
- `maui-specialist` — Shell, MVVM, platform services
- `wpf-specialist` — Generic host, compiled bindings, commands
- `di-advisor` — Lifetimes, IOptions, keyed services, factories
- `performance-profiler` — EF perf, async bottlenecks, GC, LINQ
- `deployment-validator` — Docker, k8s, Azure, IIS, config
- `deep-bug-investigator` — Root cause analysis (4 parallel subagents)
- `nuget-researcher` — NuGet evaluation with CVE cross-check

**Research/Verification (2, haiku)**

- `web-researcher` — Focused external documentation research
- `verification-runner` — `dotnet build`/`test`/`format` runner

#### Hooks (20 bash scripts)

- `format-dotnet.sh` — Auto `dotnet format` on `.cs` edit
- `iron-law-verifier.sh` — Programmatic grep for top Iron Law offenders
- `debug-statement-warning.sh` — Detect `Console.WriteLine`,
  `Debugger.Break`
- `plan-stop-reminder.sh` — STOP reminder after plan write
- `security-reminder.sh` — Checklist on auth/config edits
- `log-progress.sh` — Async progress log
- `block-dangerous-ops.sh` — Blocks `dotnet ef database drop`,
  `git push --force`, `rm -rf bin obj`
- `block-secrets-in-config.sh` — Reject raw secrets in appsettings
- `check-vulnerable-packages.sh` — `dotnet list package --vulnerable`
  on `.csproj` change
- `dotnet-failure-hints.sh` — Hints for common build/test failures
- `error-critic.sh` — Structured Critic→Refiner on 3+ repeated
  failures
- `inject-iron-laws.sh` — Injects all 34 Iron Laws on subagent start
- `setup-dirs.sh` — Creates `.claude/{plans,reviews,solutions,audit,
  scratchpad}`
- `check-scratchpad.sh` — Surfaces prior decisions on session start
- `check-resume.sh` — Detects uncompleted plans on session start
- `check-branch-freshness.sh` — Warns when branch stale vs main
- `precompact-rules.sh` — Re-injects workflow rules before compaction
- `postcompact-verify.sh` — Verifies plan state after compaction
- `stop-failure-log.sh` — Logs API failures for next-session resume
- `check-pending-plans.sh` — Warns on uncompleted plan tasks

#### 34 Iron Laws

- **C# Core (1–5)**: decimal money; no `.Result`/`.Wait()`; `using`
  IDisposable; CancellationToken propagation; nullable annotations
- **EF Core (6–12)**: AsNoTracking; parameterized SQL; single
  SaveChanges/UoW; Include before Where; FK indexes; no N+1;
  HasPrecision
- **ASP.NET Core (13–18)**: `[Authorize]` default; DTOs at boundary;
  boundary validation; rate-limited auth; CORS allowlist;
  ProblemDetails
- **Blazor (19–22)**: InvokeAsync StateHasChanged; `@key`; no WASM
  secrets; dispose subscriptions
- **MAUI/WPF (23–25)**: MVVM; ObservableCollection; weak events
- **Security (26–30)**: Parameterized SQL; PasswordHasher; secrets via
  KeyVault/UserSecrets/env; JWT full validation; anti-forgery
- **DI (31–33)**: DbContext Scoped; IHttpClientFactory; IOptions
- **Verification (34)**: No "done" without build+test output

#### Eval Framework

- 8-dimension skill scoring: completeness, accuracy, conciseness,
  triggering, safety, clarity, specificity, behavioral
- 5-dimension agent scoring: completeness, accuracy, conciseness,
  safety, consistency
- `lab/eval/generate_evals.py` — auto-generates per-skill/agent eval
  JSON
- `lab/eval/scorer.py` — single-file scorer
- `lab/eval/agent_scorer.py` — agent-specific scorer
- `lab/eval/trigger_scorer.py` — behavioral trigger cache
- 40 eval definitions + templates
- pytest suite in `lab/eval/tests/`

#### Autoresearch

- `lab/autoresearch/` scaffolding for automatic skill improvement loop
- `scripts/run-iteration.py` — mutation + scoring loop
- `references/mutation-strategies.md`, `references/state-management.md`

#### Tooling

- `Makefile` — 9 targets (help, lint, lint-fix, test, eval, eval-all,
  eval-fix, validate, ci)
- `package.json` + Husky pre-commit hook
- `.github/workflows/ci.yml` — lint + test + eval on PR
- `.github/dependabot.yml`
- `.editorconfig`, `.gitignore` (with .NET bin/obj + .vs/), `.gitattributes`
- `.markdownlint.json`, `.yamllint.yml`
- `scripts/fetch-claude-docs.sh`, `scripts/fetch-cc-changelog.sh`
- Marketplace manifest at `.claude-plugin/marketplace.json`
- Plugin manifest at `plugins/dotnet/.claude-plugin/plugin.json`

---

## Unreleased

_Next_: first user feedback, tuning of behavioral trigger cache,
potential Copilot CLI cross-compatibility (pending upstream support).

[1.0.0]: https://github.com/dimsour/dotnet-ai-toolkit/releases/tag/v1.0.0
