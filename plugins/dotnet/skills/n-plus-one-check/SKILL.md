---
name: dotnet:n-plus-one-check
description: Scan for EF Core N+1 query patterns — loops over materialized lists that access navigations, missing Include, lazy loading in hot paths. Reports file:line findings.
argument-hint: "<optional: file or directory>"
effort: medium
---

# n-plus-one-check

Targeted scan for the most common EF Core performance bug.

## What N+1 Looks Like

```csharp
// ❌ N+1 — accesses .Customer per iteration, one SQL each
var orders = await _ctx.Orders.Where(o => o.Status == "Open").ToListAsync();
foreach (var o in orders)
    Console.WriteLine(o.Customer.Name);       // lazy-load OR null

// ❌ N+1 via explicit query per item
var orders = await _ctx.Orders.ToListAsync();
foreach (var o in orders)
    o.Total = await _ctx.Items.Where(i => i.OrderId == o.Id).SumAsync(i => i.Price);

// ❌ N+1 inside a projection that escapes
var vm = orders.Select(o => new { o.Id, Name = o.Customer.Name }).ToList();
```

## Detection Patterns

Grep for these shapes:

| Pattern | Regex |
|---------|-------|
| foreach over query result + navigation | `foreach\s*\([^)]+\).*\n.*\.(Customer\|Order\|Items\|Tag)\b` |
| Query inside loop | `for(each)?\s.*\{[\s\S]*?_(db\|ctx)\.\w+\.(Where\|First\|Single\|Find)` |
| Lazy loading on | `UseLazyLoadingProxies\(\)` |
| Missing Include before projection | Queries that return entity lists without `.Include` |

## Flow

1. **Locate** all EF queries (`DbSet<T>.Where/Select/ToList/First`)
2. **Look** for sibling code — is the result iterated?
3. **Check** if any navigation is accessed in the iteration
4. **Check** if that navigation is eager-loaded (`.Include(x => x.Nav)`)
5. **Report** findings with file:line and suggested fix

## Fixes (ranked by preference)

```csharp
// ✅ 1. Project to DTO — best for read paths
await _ctx.Orders
    .Where(o => o.Status == "Open")
    .Select(o => new OrderDto(o.Id, o.Customer.Name))   // translates to SQL JOIN
    .ToListAsync(ct);

// ✅ 2. Include — for entity use (writes, deep operations)
await _ctx.Orders
    .Where(o => o.Status == "Open")
    .Include(o => o.Customer)
    .AsNoTracking()
    .ToListAsync(ct);

// ✅ 3. Batch load via .AsSplitQuery when .Include count ≥ 3
await _ctx.Orders
    .Include(o => o.Customer)
    .Include(o => o.Items).ThenInclude(i => i.Product)
    .AsSplitQuery()
    .ToListAsync(ct);
```

## Iron Laws

- **#11**: No N+1 — this skill is the enforcement tool
- **#6**: `AsNoTracking()` on read paths after fixing N+1
- Don't "fix" N+1 by disabling lazy loading silently — that just moves
  the bug to null-navigation exceptions

## Output

`.claude/audit/n-plus-one.md`:

```markdown
# N+1 Scan — 2026-04-18

## Findings (3)

### 🔴 src/Api/Orders/OrdersController.cs:47
Iterates `orders` list and accesses `.Customer.Name` without Include.
Fix: project to `OrderDto` in the query.

### 🟠 src/Services/InvoiceReport.cs:103
`.ForEach(o => LoadItems(o))` calls DbSet inside loop.
Fix: `.Include(o => o.Items)` or projection.

### 🟡 src/Admin/DashboardViewModel.cs:55
Projects via `.Select(o => o.Customer.Name)` — translated, not N+1,
but flagged for review because lazy loading is enabled project-wide
(see Program.cs:34).
```

## Integration

```
/dotnet:n-plus-one-check → .claude/audit/n-plus-one.md
        ↓
/dotnet:plan "Fix N+1 queries"
        ↓
/dotnet:work
```

## References

- `${CLAUDE_SKILL_DIR}/references/detection-rules.md` — full grep
  pattern library
- `${CLAUDE_SKILL_DIR}/references/split-query.md` — when
  `.AsSplitQuery` beats single query
- `${CLAUDE_SKILL_DIR}/references/logging-interceptor.md` — verify
  fix by counting queries in tests

## Anti-patterns

- Reporting a projected query as N+1 (it's not — EF translates)
- Suggesting `.ToList()` + loop as a "fix"
- Ignoring deeply nested `foreach` (still N+1 even if pretty)
- Not adding an integration test to lock in the fix
