---
name: migration-check
description: Validate EF Core migrations for destructive ops, downtime risk, and backward compatibility. Detects dropped columns, NOT NULL additions without defaults, data-destructive renames.
argument-hint: <optional: migration name>
effort: medium
---

# migration-check

Gate migrations before they run against production.

## When to Use

- New migration added — before `dotnet ef database update`
- Pre-deploy review
- PR contains `Migrations/*.cs` changes

## What to Check

### 🔴 Destructive (require plan)

- `DropColumn` — any column drop
- `DropTable` — table drop
- `AlterColumn` to `nullable: false` without a `defaultValue` on a
  table with existing rows
- `AlterColumn` narrowing type (`nvarchar(200) → nvarchar(50)`) —
  silent truncation risk
- `RenameColumn` — EF-level rename is an ALTER, but data migrations
  around it are often missed
- `RenameTable`

### 🟠 Risky (validate)

- New index on a huge table — lock duration
- Foreign key addition — validates all existing rows
- `AddColumn` with computed value from another column — triggers full
  table rewrite on some providers
- Any raw `migrationBuilder.Sql(...)` — read it carefully

### 🟡 Safe but Flag

- New nullable column — safe, but confirm the default/null handling
  in code
- New table — safe
- Adding a check constraint — locks briefly

## Flow

1. **List** pending migrations:

   ```bash
   dotnet ef migrations list --no-build
   ```

2. **Open** each `Up(...)` method in unchecked migrations
3. **Classify** every `migrationBuilder.*` call by severity above
4. **Report** per-migration:
   - What's destructive / risky / safe
   - Required pre-deploy steps (backfill, two-phase column rename, etc.)
   - Suggested `migrationBuilder.Sql` if a data fix is needed

## Two-Phase Patterns

### Renaming a column safely

```csharp
// Phase 1 deploy
migrationBuilder.AddColumn<string>("FullName", ..., nullable: true);
migrationBuilder.Sql("UPDATE Users SET FullName = FirstName + ' ' + LastName");
// Code writes both Old (FirstName/LastName) and New (FullName)

// Phase 2 deploy (after all app instances updated)
migrationBuilder.DropColumn("FirstName");
migrationBuilder.DropColumn("LastName");
```

### Adding NOT NULL to existing column

```csharp
// Phase 1: add column nullable + backfill
migrationBuilder.AddColumn<int>("TenantId", ..., nullable: true);
migrationBuilder.Sql("UPDATE Orders SET TenantId = 1 WHERE TenantId IS NULL");

// Phase 2 (separate migration, after backfill completes):
migrationBuilder.AlterColumn<int>("TenantId", ..., nullable: false);
```

## Iron Laws

- **#7**: Parameterized SQL — applies to raw SQL in migrations too
- Never drop a column in the same migration that adds its replacement
- Never deploy a migration whose `Down()` doesn't actually reverse
  `Up()` (or doesn't exist)
- Never run migrations against prod without a tested rollback plan

## Output

`.claude/audit/migration-{name}.md`:

```markdown
# Migration: 20260418_AddTenantScope

## Operations
- AddColumn Users.TenantId (int, nullable: false, default: 0) 🟠
- AddForeignKey Users.TenantId → Tenants.Id 🟠
- CreateIndex Users.TenantId 🟢

## Risks
- NOT NULL with default `0` on existing Users → every existing row
  gets TenantId=0. Is that the intended "root" tenant?
- FK validation on 2.3M users. Estimate: ~45s on prod DB.

## Recommendation
Two-phase:
1. This migration, minus the NOT NULL — deploy + backfill via script
2. Next migration: AlterColumn nullable: false after verification
```

## Integration

```
dotnet ef migrations add X
        ↓
/dotnet:migration-check
        ↓
fix issues / approve
        ↓
/dotnet:review → deploy
```

## References

- `${CLAUDE_SKILL_DIR}/references/destructive-ops.md` — full list +
  safe alternative
- `${CLAUDE_SKILL_DIR}/references/two-phase-patterns.md` — column
  rename, type change, NOT NULL, FK add
- `${CLAUDE_SKILL_DIR}/references/rollback.md` — Down() patterns,
  data preservation

## Anti-patterns

- Skipping migration review because "EF generated it"
- Deploying NOT NULL additions without backfill
- Missing `Down()` methods — no rollback path
- `migrationBuilder.Sql(...)` with interpolation — same SQL injection
  risk as app code
