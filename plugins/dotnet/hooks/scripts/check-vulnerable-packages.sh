#!/usr/bin/env bash
# PostToolUse hook (async): Scan for vulnerable NuGet packages when a .csproj changes.
# Uses `dotnet list package --vulnerable --include-transitive`.

FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0
[[ "$FILE_PATH" == *.csproj ]] || exit 0
[[ -f "$FILE_PATH" ]] || exit 0

# Must be able to restore first — skip if offline / no network
if ! command -v dotnet >/dev/null 2>&1; then
  exit 0
fi

OUTPUT=$(dotnet list "$FILE_PATH" package --vulnerable --include-transitive 2>&1 || true)

# If the word "vulnerabilities" doesn't appear in output or it says "no vulnerable", skip
if echo "$OUTPUT" | grep -qiE 'has the following vulnerable packages'; then
  FINDINGS=$(echo "$OUTPUT" | grep -E '^\s*>' | head -20)
  cat >&2 <<MSG
VULNERABLE NUGET PACKAGES in $(basename "$FILE_PATH"):
$FINDINGS

Run 'dotnet list package --vulnerable --include-transitive' for full details.
Update affected packages to patched versions before merging.
MSG
  exit 2
fi

exit 0
