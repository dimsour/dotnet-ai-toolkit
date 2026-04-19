#!/usr/bin/env bash
# PostToolUse hook: Check .NET file formatting after Edit/Write
# Only warns — does NOT modify files (prevents "file modified since read" race condition)
FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
[[ "$FILE_PATH" == *.cs ]] || exit 0
[[ -f "$FILE_PATH" ]] || exit 0

# Try to locate nearest .csproj / .sln to scope dotnet format
DIR="$(dirname "$FILE_PATH")"
PROJECT=""
while [[ "$DIR" != "/" && "$DIR" != "." ]]; do
  CSPROJ=$(ls "$DIR"/*.csproj 2>/dev/null | head -1)
  if [[ -n "$CSPROJ" ]]; then
    PROJECT="$CSPROJ"
    break
  fi
  DIR="$(dirname "$DIR")"
done

# If no project found, skip silently (might be a loose script file)
[[ -n "$PROJECT" ]] || exit 0

# Use --verify-no-changes to detect without modifying
if ! dotnet format "$PROJECT" --verify-no-changes --include "$FILE_PATH" >/dev/null 2>&1; then
  # PostToolUse: exit 2 + stderr feeds message to Claude (stdout is verbose-mode only)
  echo "NEEDS FORMAT: $FILE_PATH — run 'dotnet format $PROJECT --include $FILE_PATH' before committing" >&2
  exit 2
fi
