#!/usr/bin/env python3
"""Generate plugins/dotnet-copilot/ from plugins/dotnet/ (Claude source of truth).

Transforms Claude Code plugin format -> GitHub Copilot CLI plugin format.

Run via: make build-copilot
"""

from __future__ import annotations

import json
import os
import re
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SRC = REPO_ROOT / "plugins" / "dotnet"
DST = REPO_ROOT / "plugins" / "dotnet-copilot"

# Frontmatter keys to drop on agents (Claude-specific, ignored by Copilot).
AGENT_DROP_KEYS = {
    "disallowedTools", "permissionMode", "effort", "omitClaudeMd",
    "skills", "maxTurns", "memory",
}

# Hook entry keys to drop (Copilot flat schema doesn't use these).
HOOK_ENTRY_DROP = {"if", "matcher", "async", "statusMessage"}


def split_frontmatter(text: str) -> tuple[dict, str, list[str]]:
    """Return (frontmatter_dict, body, raw_frontmatter_lines).

    Manual line-based parser to preserve key order and avoid PyYAML dependency.
    Handles only the simple key: value | block-scalar | list shapes our files use.
    """
    if not text.startswith("---\n"):
        return {}, text, []
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}, text, []
    fm_text = text[4:end]
    body = text[end + 5:]
    lines = fm_text.split("\n")

    fm: dict[str, object] = {}
    current_list_key: str | None = None
    for raw in lines:
        if not raw.strip():
            continue
        if raw.startswith("  - ") or raw.startswith("- "):
            if current_list_key is not None:
                fm[current_list_key].append(raw.lstrip(" -").strip())  # type: ignore[union-attr]
            continue
        m = re.match(r"^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$", raw)
        if not m:
            continue
        key, val = m.group(1), m.group(2)
        if val == "":
            current_list_key = key
            fm[key] = []
        else:
            current_list_key = None
            fm[key] = val.strip()
    return fm, body, lines


def render_frontmatter(fm: dict) -> str:
    """Re-emit frontmatter dict as YAML in original key-order."""
    out = ["---"]
    for k, v in fm.items():
        if isinstance(v, list):
            out.append(f"{k}:")
            for item in v:
                out.append(f"  - {item}")
        else:
            out.append(f"{k}: {v}")
    out.append("---\n")
    return "\n".join(out)


# ---------- skills ----------

def transform_skill(skill_dir: Path, dst_skills: Path) -> None:
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        return
    text = skill_md.read_text()
    fm, body, _ = split_frontmatter(text)

    # Strip dotnet: prefix from name field — Copilot CLI silently drops skills
    # whose name field contains a colon. The plugin name auto-prefixes the
    # slash command, so /dotnet:plan still works.
    name = fm.get("name", "")
    if isinstance(name, str) and name.startswith("dotnet:"):
        fm["name"] = name.split(":", 1)[1]

    out_dir = dst_skills / skill_dir.name
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "SKILL.md").write_text(render_frontmatter(fm) + body)

    refs = skill_dir / "references"
    if refs.is_dir():
        shutil.copytree(refs, out_dir / "references", dirs_exist_ok=True)


# ---------- agents ----------

def transform_agent(agent_md: Path, dst_agents: Path) -> None:
    text = agent_md.read_text()
    fm, body, _ = split_frontmatter(text)

    # Drop Claude-only keys; keep name, description, tools, model.
    for k in list(fm):
        if k in AGENT_DROP_KEYS:
            del fm[k]

    out = dst_agents / f"{agent_md.stem}.agent.md"
    out.write_text(render_frontmatter(fm) + body)


# ---------- hooks ----------

def flatten_hook_group(group: dict) -> list[dict]:
    """Claude nests {matcher, hooks: [{...}]}; Copilot wants a flat list of
    {type, bash, timeoutSec}. Translate each inner entry."""
    out: list[dict] = []
    for entry in group.get("hooks", []):
        if entry.get("type") != "command":
            continue
        flat: dict[str, object] = {"type": "command"}
        if "command" in entry:
            flat["bash"] = entry["command"]
        if "timeout" in entry:
            flat["timeoutSec"] = entry["timeout"]
        for k, v in entry.items():
            if k in {"type", "command", "timeout"} or k in HOOK_ENTRY_DROP:
                continue
            flat[k] = v
        out.append(flat)
    return out


def transform_hooks(src_hooks_json: Path, dst_hooks_dir: Path) -> None:
    raw = json.loads(src_hooks_json.read_text())
    src_events = raw.get("hooks", {})

    out_events: dict[str, list[dict]] = {}
    for event_name, groups in src_events.items():
        # Keep PascalCase event names — Copilot CLI v1.0.6+ accepts them.
        flat: list[dict] = []
        for group in groups:
            flat.extend(flatten_hook_group(group))
        if flat:
            out_events[event_name] = flat

    dst_hooks_dir.mkdir(parents=True, exist_ok=True)
    out_path = dst_hooks_dir / "hooks.json"
    out_path.write_text(json.dumps({"version": 1, "hooks": out_events}, indent=2) + "\n")

    # Replace ${CLAUDE_PLUGIN_ROOT} so user-installed setup workaround works.
    # Copilot v1.0.32+ sets this env var for plugin hooks, but we ship scripts
    # that resolve it themselves.
    src_scripts = src_hooks_json.parent / "scripts"
    dst_scripts = dst_hooks_dir / "scripts"
    if src_scripts.is_dir():
        shutil.copytree(src_scripts, dst_scripts, dirs_exist_ok=True)
        for sh in dst_scripts.glob("*.sh"):
            os.chmod(sh, 0o755)


# ---------- setup-hooks.sh workaround for bug #2540 ----------

SETUP_HOOKS_SH = """#!/usr/bin/env bash
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
        return s.replace("\\${CLAUDE_PLUGIN_ROOT}/hooks/scripts", dest_scripts)
    return s
def walk(o):
    if isinstance(o, dict):
        return {k: walk(rewrite(v)) for k, v in o.items()}
    if isinstance(o, list):
        return [walk(rewrite(x)) for x in o]
    return rewrite(o)
out = pathlib.Path(os.path.expanduser("~/.copilot/hooks/hooks.json"))
out.write_text(json.dumps(walk(data), indent=2) + "\\n")
print(f"Installed hooks to {out}")
PY

echo
echo "Hooks installed to ~/.copilot/hooks/"
echo "They will fire on the next 'copilot' session."
echo "To uninstall: rm -rf ~/.copilot/hooks/scripts ~/.copilot/hooks/hooks.json"
"""


# ---------- plugin.json ----------

def write_plugin_manifest() -> None:
    src = json.loads((SRC / ".claude-plugin" / "plugin.json").read_text())
    # Keep the plugin's internal name as "dotnet" so slash commands resolve
    # to /dotnet:plan, /dotnet:work, etc. — matching the Claude variant.
    # The marketplace listing uses "dotnet-copilot" as the install identifier.
    out = {
        "name": "dotnet",
        "version": src.get("version", "1.0.0"),
        "description": src.get("description", ""),
        "keywords": src.get("keywords", []),
        "author": src.get("author", {}),
        "homepage": src.get("homepage", ""),
        "repository": src.get("repository", ""),
        "agents": "agents/",
        "skills": "skills/",
        "hooks": "hooks/hooks.json",
    }
    manifest_dir = DST / ".copilot-plugin"
    manifest_dir.mkdir(parents=True, exist_ok=True)
    (manifest_dir / "plugin.json").write_text(json.dumps(out, indent=2) + "\n")
    # Also put one at .claude-plugin/ — Copilot CLI checks both paths.
    cc_dir = DST / ".claude-plugin"
    cc_dir.mkdir(parents=True, exist_ok=True)
    (cc_dir / "plugin.json").write_text(json.dumps(out, indent=2) + "\n")


# ---------- README for the variant ----------

VARIANT_README = """# dotnet-copilot

GitHub Copilot CLI variant of the dotnet-ai-toolkit plugin.

**Auto-generated.** Do not edit files here directly — edit `plugins/dotnet/`
and re-run `make build-copilot`.

## Install

```bash
copilot
> /plugin marketplace add <repo-url>
> /plugin install dotnet-copilot
```

## Activate hooks (one-time, workaround for [copilot-cli#2540](https://github.com/github/copilot-cli/issues/2540))

```bash
bash ~/.copilot/installed-plugins/<marketplace>/dotnet-copilot/setup-hooks.sh
```

This copies hook scripts into `~/.copilot/hooks/` where they actually fire.
Remove this step once GitHub fixes plugin-shipped hook loading.

## Differences from the Claude variant

- Skill `name:` fields stripped of `dotnet:` prefix (Copilot CLI rejects
  colons in skill names; the plugin name auto-prefixes the slash command,
  so `/dotnet:plan` still works)
- Agents renamed `*.md` -> `*.agent.md` (Copilot's required extension)
- Agent frontmatter trimmed: `disallowedTools`, `permissionMode`,
  `omitClaudeMd`, `effort`, `memory`, `skills`, `maxTurns` removed
  (silently ignored by Copilot anyway, but kept clean)
- Hook entries flattened from Claude's `{matcher, hooks: [...]}` shape to
  Copilot's flat `[{type, bash, timeoutSec}]` shape
- PascalCase event names retained (Copilot CLI v1.0.6+ accepts them and
  emits Claude-compatible payloads)
"""


# ---------- main ----------

def reset_dst() -> None:
    if DST.exists():
        shutil.rmtree(DST)
    DST.mkdir(parents=True)


def main() -> int:
    print(f"Source: {SRC}")
    print(f"Target: {DST}")
    if not SRC.is_dir():
        print(f"ERROR: source not found: {SRC}", file=sys.stderr)
        return 1
    reset_dst()

    # Skills
    dst_skills = DST / "skills"
    dst_skills.mkdir(parents=True)
    skill_count = 0
    for skill_dir in sorted((SRC / "skills").iterdir()):
        if skill_dir.is_dir():
            transform_skill(skill_dir, dst_skills)
            skill_count += 1

    # Agents
    dst_agents = DST / "agents"
    dst_agents.mkdir(parents=True)
    agent_count = 0
    for agent_md in sorted((SRC / "agents").glob("*.md")):
        transform_agent(agent_md, dst_agents)
        agent_count += 1

    # Hooks
    transform_hooks(SRC / "hooks" / "hooks.json", DST / "hooks")

    # Plugin manifest (in two locations Copilot CLI checks)
    write_plugin_manifest()

    # Setup workaround
    (DST / "setup-hooks.sh").write_text(SETUP_HOOKS_SH)
    os.chmod(DST / "setup-hooks.sh", 0o755)

    # Variant README
    (DST / "README.md").write_text(VARIANT_README)

    print(f"  skills:  {skill_count}")
    print(f"  agents:  {agent_count}")
    print(f"  hooks:   1 hooks.json + {len(list((DST / 'hooks' / 'scripts').glob('*.sh')))} scripts")
    print(f"  setup:   setup-hooks.sh")
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
