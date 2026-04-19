# dotnet-copilot

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
