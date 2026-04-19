#!/bin/bash
# Fetch latest Claude Code changelog for the /cc-changelog contributor skill.
# Output: .claude/cc-changelog/changelog-cache.md

set -euo pipefail

CACHE_DIR=".claude/cc-changelog"
mkdir -p "$CACHE_DIR"
OUT="$CACHE_DIR/changelog-cache.md"

URL="https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"

echo "Fetching Claude Code changelog to $OUT..."
if command -v curl &>/dev/null; then
  curl -sL "$URL" -o "$OUT" && echo "Saved $(wc -l < "$OUT") lines."
else
  echo "curl not available — cannot fetch"
  exit 1
fi
