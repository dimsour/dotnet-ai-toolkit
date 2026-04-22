---
name: dotnet:document
description: Generate or update documentation — XML doc comments, README, architecture docs, OpenAPI descriptions. Uses code as source of truth; no hallucinated features.
argument-hint: "<file|directory|topic>"
effort: medium
---

# document

Produce accurate documentation from actual code. Never invent features.

## When to Use

- Public API lacks XML doc comments
- README outdated vs actual commands / endpoints
- New architecture needs onboarding doc
- OpenAPI / Swagger descriptions are thin

Not for: marketing copy, vague "overview" docs, or speculative future
features.

## Flow

1. **Scope** the documentation target (file, project, or topic)
2. **Read** the actual code — every claim must trace to a specific
   file:line or attribute
3. **Generate** documentation in the appropriate format (see below)
4. **Diff** against existing doc — preserve user additions; update
   only stale sections
5. **Verify** code samples compile (if we're showing call sites)

## Formats

### XML Doc Comments (C#)

```csharp
/// <summary>
/// Creates a new order for the specified customer.
/// </summary>
/// <param name="request">The order details — customer and items.</param>
/// <param name="ct">Cancellation token propagated from the caller.</param>
/// <returns>The persisted order with server-assigned ID and timestamps.</returns>
/// <exception cref="ValidationException">
/// Thrown when items is empty or any quantity is non-positive.
/// </exception>
public Task<Order> CreateAsync(CreateOrderRequest request, CancellationToken ct);
```

Rules:

- `<summary>` = one sentence, verb-first
- `<param>`, `<returns>`, `<exception>` only for public API
- Reference types with `<see cref="..."/>`

### README sections

- **What**: one paragraph
- **Install / Setup**: exact commands
- **Quickstart**: 3–5 copy-pasteable commands
- **Structure**: tree with one-line purpose per folder
- **Common tasks**: verb-first headings

### Architecture Doc

- Problem / Context → Decision → Consequences (ADR format)
- Diagram (Mermaid preferred; ASCII acceptable)
- References (PRs, RFCs, related docs)

### OpenAPI

- Every endpoint has `summary` + `description`
- Every DTO property has `description`
- Error responses documented with `Problem` schema ref

## Iron Laws

- **Never document features that don't exist in code** — hallucinated
  features erode trust
- **Never delete user-authored prose** — generate new sections, merge
  carefully
- Code samples must compile — test before committing

## Output

In-place edits to existing doc files, or new `.md` / `README.md` at
sensible paths.

## Integration

```
/dotnet:work (feature complete)
        ↓
/dotnet:document
        ↓
/dotnet:review (docs count as code)
```

## References

- `${CLAUDE_SKILL_DIR}/references/xml-doc-style.md` — C# doc comment
  conventions
- `${CLAUDE_SKILL_DIR}/references/readme-template.md` — structure and
  tone
- `${CLAUDE_SKILL_DIR}/references/adr-format.md` — Architecture
  Decision Record template
- `${CLAUDE_SKILL_DIR}/references/openapi-patterns.md` — generating
  rich OpenAPI from Minimal APIs

## Anti-patterns

- Restating the code in prose ("this method takes an int and returns
  an int")
- Documenting trivial private methods
- XML doc comments that duplicate the method signature without adding
  context
- "TODO: add more detail" placeholders left in committed doc
