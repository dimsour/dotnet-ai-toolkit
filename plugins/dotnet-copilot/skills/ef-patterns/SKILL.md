---
name: ef-patterns
description: Entity Framework Core patterns — queries, migrations, relationships, concurrency, performance. Auto-loads for DbContext/migration work.
effort: medium
---

# ef-patterns

Entity Framework Core reference for .NET 8–11 (EF Core 8/9/10/11).

## Iron Laws

- **#6**: `AsNoTracking()` on read-only queries
- **#7**: Parameterize SQL — never `FromSqlRaw($"... {input}")`
- **#8**: One `SaveChangesAsync` per Unit of Work
- **#9**: `.Include(...)` BEFORE `.Where(...)` for nav loading
- **#10**: Index foreign keys
- **#11**: No N+1 — use `.Include` / `.AsSplitQuery`
- **#12**: `HasPrecision(p, s)` on decimal properties
- **#31**: DbContext = `Scoped` in DI

## Core Patterns

### Query — read-only

```csharp
var orders = await _db.Orders
    .AsNoTracking()
    .Where(o => o.CustomerId == customerId && o.Status == OrderStatus.Pending)
    .Include(o => o.Items)
        .ThenInclude(i => i.Product)
    .AsSplitQuery()
    .Select(o => new OrderDto(o.Id, o.Total, o.Items.Count))
    .ToListAsync(ct);
```

### Mutation — Unit of Work

```csharp
var order = await _db.Orders.FindAsync([orderId], ct);
order.MarkPaid(paidAt: DateTimeOffset.UtcNow);
await _db.SaveChangesAsync(ct);  // ONE call, not in a loop
```

### Batch update (EF Core 7+)

```csharp
await _db.Orders
    .Where(o => o.CreatedAt < cutoff)
    .ExecuteUpdateAsync(set => set.SetProperty(o => o.IsArchived, true), ct);
```

### Concurrency

```csharp
public class Order
{
    // ...
    [Timestamp] public byte[] RowVersion { get; set; } = null!;
}

try { await _db.SaveChangesAsync(ct); }
catch (DbUpdateConcurrencyException ex)
{
    // reload + retry OR surface 409 Conflict
}
```

### Entity Configuration

```csharp
public class OrderConfig : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Total).HasPrecision(18, 2);  // Iron Law #12
        b.Property(x => x.Status).HasConversion<string>().HasMaxLength(32);
        b.HasOne(x => x.Customer)
            .WithMany(c => c.Orders)
            .HasForeignKey(x => x.CustomerId)
            .OnDelete(DeleteBehavior.Restrict);
        b.HasIndex(x => x.CustomerId);  // Iron Law #10
        b.HasIndex(x => new { x.Status, x.CreatedAt });
    }
}
```

### Migrations — safe additive

```bash
dotnet ef migrations add AddOrderStatusIndex -p src/Data
dotnet ef database update -p src/Data
```

```csharp
// In generated Up():
migrationBuilder.CreateIndex(
    name: "IX_Orders_Status_CreatedAt",
    table: "Orders",
    columns: new[] { "Status", "CreatedAt" });
```

### Raw SQL — parameterized

```csharp
// ✅ Safe — FromSqlInterpolated escapes
var name = "O'Brien";
var rows = await _db.Users
    .FromSqlInterpolated($"SELECT * FROM Users WHERE LastName = {name}")
    .ToListAsync(ct);

// ❌ NEVER
var rows = await _db.Users
    .FromSqlRaw($"SELECT * FROM Users WHERE LastName = '{name}'")  // SQL injection
    .ToListAsync(ct);
```

## References

- `${CLAUDE_SKILL_DIR}/references/queries.md` — projection, filtering,
  split queries, compiled queries
- `${CLAUDE_SKILL_DIR}/references/migrations.md` — additive/breaking/data
  migrations
- `${CLAUDE_SKILL_DIR}/references/relationships.md` — one-to-many, M:N,
  owned types
- `${CLAUDE_SKILL_DIR}/references/concurrency.md` — optimistic,
  RowVersion, conflict resolution
- `${CLAUDE_SKILL_DIR}/references/performance.md` — AsNoTracking, split,
  compiled, batched, bulk ext
- `${CLAUDE_SKILL_DIR}/references/json-columns.md` — EF Core 7+ JSON
- `${CLAUDE_SKILL_DIR}/references/complex-types.md` — EF Core 8+

## Anti-patterns

- `SaveChangesAsync` inside a loop (Iron Law #8)
- `.ToList()` then in-memory filter (should be `.Where()` server-side)
- `Include` with `ThenInclude` without `AsSplitQuery` on collections
  (Cartesian explosion)
- Long-lived DbContext accumulating tracked entities
- Missing `.HasPrecision` on decimal — silently-wrong money values
