#!/usr/bin/env bash
# Workaround for github/copilot-cli#2540: plugin-shipped hooks.json doesn't
# fire. This installs the plugin's hooks into ~/.copilot/hooks/ where they
# do fire. Run once after `/plugin install dotnet-copilot`.
set -euo pipefail

PLUGIN_ROOT="${COPILOT_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")" && pwd)}}"
DEST="$HOME/.copilot/hooks"

mkdir -p "$DEST/scripts"
cp -R "$PLUGIN_ROOT/hooks/scripts/." "$DEST/scripts/"
chmod +x "$DEST/scripts/"*.sh 2>/dev/null || true

# Rewrite hooks.json so script paths resolve to the personal install dir.
python3 - <<PY
import json, os, pathlib
src = pathlib.Path("$PLUGIN_ROOT/hooks/hooks.json").read_text()
data = json.loads(src)
dest_scripts = os.path.expanduser("~/.copilot/hooks/scripts")
def rewrite(s):
    if isinstance(s, str):
        return s.replace("\${CLAUDE_PLUGIN_ROOT}/hooks/scripts", dest_scripts)
    return s
def walk(o):
    if isinstance(o, dict):
        return {k: walk(rewrite(v)) for k, v in o.items()}
    if isinstance(o, list):
        return [walk(rewrite(x)) for x in o]
    return rewrite(o)
out = pathlib.Path(os.path.expanduser("~/.copilot/hooks/hooks.json"))
out.write_text(json.dumps(walk(data), indent=2) + "\n")
print(f"Installed hooks to {out}")
PY

echo
echo "Hooks installed to ~/.copilot/hooks/"
echo "They will fire on the next 'copilot' session."
echo "To uninstall: rm -rf ~/.copilot/hooks/scripts ~/.copilot/hooks/hooks.json"
