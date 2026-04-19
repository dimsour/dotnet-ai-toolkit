#!/usr/bin/env bash
# PostToolUse hook: Warn about debug statements left in C# files.
# Catches Console.WriteLine, Debug.WriteLine, Debugger.Break, #if DEBUG leftovers.

FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0
[[ "$FILE_PATH" == *.cs ]] || exit 0
[[ -f "$FILE_PATH" ]] || exit 0

# Skip test projects
[[ "$FILE_PATH" == *Test*.cs ]] && exit 0
[[ "$FILE_PATH" == *Tests*.cs ]] && exit 0
[[ "$FILE_PATH" == */test/* ]] && exit 0
[[ "$FILE_PATH" == */tests/* ]] && exit 0

# Skip Program.cs (legitimate Console.WriteLine for CLI/setup)
[[ "$(basename "$FILE_PATH")" == "Program.cs" ]] && exit 0

DEBUGS=""

# Console.WriteLine — most common leftover
MATCH=$(grep -n 'Console\.WriteLine' "$FILE_PATH" 2>/dev/null | head -3)
if [[ -n "$MATCH" ]]; then
  DEBUGS="${DEBUGS}\n  Console.WriteLine:\n${MATCH}"
fi

# Debug.WriteLine
MATCH=$(grep -n 'Debug\.WriteLine' "$FILE_PATH" 2>/dev/null | head -3)
if [[ -n "$MATCH" ]]; then
  DEBUGS="${DEBUGS}\n  Debug.WriteLine:\n${MATCH}"
fi

# Debugger.Break
MATCH=$(grep -n 'Debugger\.Break\(\)' "$FILE_PATH" 2>/dev/null | head -3)
if [[ -n "$MATCH" ]]; then
  DEBUGS="${DEBUGS}\n  Debugger.Break():\n${MATCH}"
fi

if [[ -n "$DEBUGS" ]]; then
  cat >&2 <<MSG
DEBUG STATEMENTS in $(basename "$FILE_PATH"):
$(echo -e "$DEBUGS")

Remove before committing. Use ILogger<T> for intentional logging.
MSG
  exit 2
fi
