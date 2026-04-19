---
name: dotnet:permissions
description: Configure Claude Code permissions to reduce prompts — common .NET commands (dotnet build/test/format/ef), file-write allowlist. Use after first permission-prompt fatigue.
effort: low
---

# permissions

Streamline the permission prompt flow for .NET projects.

## When to Use

- Claude keeps prompting for `dotnet build`, `dotnet test`, `dotnet ef`
- Many `Bash` prompts for standard workflow commands
- User wants to lock down which writes are allowed

Not for: bypassing safety on unknown commands.

## Settings Template

Write to `.claude/settings.json` (per-project) or
`~/.claude/settings.json` (user-wide):

```json
{
  "permissions": {
    "allow": [
      "Bash(dotnet build:*)",
      "Bash(dotnet test:*)",
      "Bash(dotnet format:*)",
      "Bash(dotnet restore:*)",
      "Bash(dotnet run:*)",
      "Bash(dotnet tool restore)",
      "Bash(dotnet list package:*)",
      "Bash(dotnet ef migrations list)",
      "Bash(dotnet ef migrations add:*)",
      "Bash(dotnet ef migrations script:*)",
      "Bash(dotnet user-secrets:*)",

      "Bash(git status)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",

      "Bash(gh pr view:*)",
      "Bash(gh pr diff:*)",

      "Read(src/**)",
      "Read(tests/**)",
      "Edit(src/**)",
      "Edit(tests/**)",
      "Write(.claude/**)"
    ],
    "deny": [
      "Bash(dotnet ef database drop:*)",
      "Bash(dotnet ef database update:*)",
      "Bash(git push --force:*)",
      "Bash(rm -rf:*)",
      "Edit(appsettings.Production.json)",
      "Edit(*.env)",
      "Edit(secrets.json)"
    ]
  }
}
```

## Flow

1. Ask user: project-level or user-level?
2. Ask: which workflow commands do you run often?
3. Merge with existing `settings.json` (preserve user additions)
4. Write and show the diff

## Iron Laws

- Never allow `dotnet ef database drop` broadly — destructive
- Never allow unrestricted `rm -rf` or `git push --force`
- Keep `Edit(appsettings.Production.json)` denied — secrets risk
- Use narrow allowlists when possible (`Bash(dotnet test:*)` not
  `Bash(dotnet*)`)

## Risky Patterns to Always Deny

```json
"deny": [
  "Bash(dotnet ef database drop:*)",
  "Bash(git push --force:*)",
  "Bash(git push --force-with-lease:*)",
  "Bash(git reset --hard:*)",
  "Bash(rm -rf:*)",
  "Bash(rm -fr:*)",
  "Edit(appsettings.Production*)",
  "Edit(.env*)",
  "Write(.git/**)"
]
```

## Integration

```
/dotnet:permissions → .claude/settings.json diff → user approves
        ↓
fewer prompts on next session start
```

## References

- `${CLAUDE_SKILL_DIR}/references/glob-patterns.md` — how allow/deny
  globs match commands
- `${CLAUDE_SKILL_DIR}/references/dotnet-commands.md` — full list of
  common `dotnet` subcommands with risk rating
- `${CLAUDE_SKILL_DIR}/references/deny-list.md` — destructive
  commands that must stay denied

## Anti-patterns

- `"allow": ["Bash(*)"]` — completely defeats safety
- Allowing `git push --force` without `--force-with-lease`
- Allowing `appsettings.Production.json` writes
- Permissive `Edit(**)` without a deny list covering secrets
