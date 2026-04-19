#!/usr/bin/env bash
# PreToolUse hook: Block dangerous operations before execution.
# Extends the action-verifier pattern (iron-law-verifier.sh)
# to catch destructive operations BEFORE they run.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only check Bash commands
[[ "$TOOL" == "Bash" ]] || exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -n "$COMMAND" ]] || exit 0

# Block destructive database operations
if echo "$COMMAND" | grep -qE 'dotnet ef database drop'; then
  cat >&2 <<MSG
BLOCKED: Destructive database operation detected.
'dotnet ef database drop' will destroy all data. If intentional, run manually
outside Claude Code. Safer alternatives:
- dotnet ef migrations remove       (undo last unapplied migration)
- dotnet ef database update <target> (roll back to specific migration)
MSG
  exit 2
fi

# Block force push
if echo "$COMMAND" | grep -qE 'git push.*(--force|-f)\b'; then
  cat >&2 <<MSG
BLOCKED: Force push detected — this rewrites remote history.
If intentional, run manually outside Claude Code.
Safer alternative: git push --force-with-lease
MSG
  exit 2
fi

# Block rm -rf on bin/ or obj/ at root (destroys build artifacts during a build)
if echo "$COMMAND" | grep -qE 'rm[[:space:]]+-[rRf]*f[rR]*[[:space:]]+.*(^|/)(bin|obj)(/|$|[[:space:]])'; then
  cat >&2 <<MSG
BLOCKED: rm -rf on bin/ or obj/ detected.
Use 'dotnet clean' instead — it handles all projects in the solution safely.
MSG
  exit 2
fi

# Warn about production config in dev
if echo "$COMMAND" | grep -qE 'ASPNETCORE_ENVIRONMENT=Production|DOTNET_ENVIRONMENT=Production'; then
  cat >&2 <<MSG
WARNING: Production environment variable detected.
If building a release, this is expected. Otherwise, reconsider.
MSG
  exit 2
fi

# Warn about dangerous memory dumps in prod
if echo "$COMMAND" | grep -qE 'dotnet-(gcdump|dump)[[:space:]]+collect.*--process-id'; then
  cat >&2 <<MSG
WARNING: Memory dump tool detected.
If this is a prod process, ensure authorization and disk space.
Dumps may contain secrets and PII — handle carefully.
MSG
  exit 2
fi
