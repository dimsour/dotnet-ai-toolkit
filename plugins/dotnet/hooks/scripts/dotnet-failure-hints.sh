#!/usr/bin/env bash
# PostToolUseFailure hook: Provide .NET-specific debugging hints when Bash commands fail.
# Only triggers for dotnet build/test/restore failures. Uses additionalContext to guide Claude.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
ERROR=$(echo "$INPUT" | jq -r '.error // empty')

# Only handle dotnet-related failures
echo "$COMMAND" | grep -qE '(^|[[:space:]])dotnet\b' || exit 0

HINTS=""

if echo "$COMMAND" | grep -qE 'dotnet build'; then
  HINTS="Build failure hints:
- Read the FIRST error (CS####) — later errors are often cascading
- CS0246 (type not found): missing using, missing package reference, or not restored
- CS1061 (no member): nullable mismatch, or you renamed without updating callers
- CS8618 (non-nullable uninitialized): add = null! sparingly, or mark nullable
- If NuGet package is missing: run 'dotnet restore' first
- Scope fix to files YOU changed — pre-existing warnings are not your problem"
elif echo "$COMMAND" | grep -qE 'dotnet test'; then
  HINTS="Test failure hints:
- Read the assertion message carefully — expected vs actual
- For xUnit: check [Fact] vs [Theory] + [InlineData] mismatch
- For integration tests: WebApplicationFactory may need custom AddInMemoryCollection for config
- For flaky async tests: missing await on the SUT? Missing CancellationToken propagation?
- For DbContext tests: use InMemory or SQLite provider; isolate with per-test Respawn
- Run a single test: dotnet test --filter 'FullyQualifiedName~MyTestClass.MyMethod'"
elif echo "$COMMAND" | grep -qE 'dotnet format'; then
  HINTS="Format failure hints:
- Ensure your .editorconfig has consistent indent/brace style
- Run 'dotnet format --verify-no-changes' to diagnose without modifying
- Run 'dotnet format --include <file>' to scope to one file
- If analyzer diagnostic blocks format, fix the analyzer issue first"
elif echo "$COMMAND" | grep -qE 'dotnet ef'; then
  HINTS="EF Core migration hints:
- 'Unable to create an object': DbContext ctor or IDesignTimeDbContextFactory missing
- 'No migrations': did you run 'dotnet ef migrations add <Name>' in the correct project?
- 'Pending model changes': schema drifted — add a new migration
- For apply failures: check data violates new constraints (NOT NULL, unique, FK)
- Never 'dotnet ef database drop' in shared/prod envs — use migrations down"
elif echo "$COMMAND" | grep -qE 'dotnet restore'; then
  HINTS="Restore failure hints:
- NU1101 (package not found): check spelling, check private feed auth (nuget.config)
- NU1605 (detected package downgrade): a transitive dependency conflict
- Try: dotnet restore --force-evaluate
- Clear NuGet cache if caching a bad artifact: dotnet nuget locals all --clear"
elif echo "$COMMAND" | grep -qE 'dotnet run'; then
  HINTS="Run failure hints:
- StartupException/InvalidOperationException on boot: usually DI — a service requires something not registered
- Check launchSettings.json for expected profile + port
- For ASP.NET: Kestrel port conflict? Another process on the same port?
- For appsettings errors: missing keys in Development env? User Secrets not set?"
fi

if [ -n "$HINTS" ]; then
  echo "$HINTS" | jq -Rs '{hookSpecificOutput: {hookEventName: "PostToolUseFailure", additionalContext: .}}'
fi
