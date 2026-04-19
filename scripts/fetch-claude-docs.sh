#!/bin/bash
# Fetch latest Claude Code documentation for the /docs-check contributor skill.
# Output: .claude/docs-check/docs-cache/*.md

set -euo pipefail

CACHE_DIR=".claude/docs-check/docs-cache"
mkdir -p "$CACHE_DIR"

BASE="https://docs.claude.com/en/docs/claude-code"
PAGES=(
  "overview"
  "quickstart"
  "hooks"
  "plugins"
  "sub-agents"
  "slash-commands"
  "settings"
  "mcp"
)

echo "Fetching Claude Code docs to $CACHE_DIR..."
for page in "${PAGES[@]}"; do
  url="$BASE/$page"
  out="$CACHE_DIR/${page}.md"
  echo "  -> $url"
  if command -v curl &>/dev/null; then
    curl -sL "$url" -o "$out" || echo "  (failed $page, skipping)"
  else
    echo "  curl not available — skipping"
    exit 0
  fi
done

echo "Done."
