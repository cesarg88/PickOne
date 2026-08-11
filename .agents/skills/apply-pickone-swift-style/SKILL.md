---
name: apply-pickone-swift-style
description: Apply PickOne's Swift and SwiftUI coding conventions when writing, refactoring, or reviewing production or test Swift code. Use for any change to .swift files, including Domain, Data, Presentation, composition, test doubles, fixtures, and tests; pair it with the implementation or review skill for those workflows.
---

# Apply PickOne Swift Style

## Resolve authority

1. Read `ENGINEERING.md`; it owns architecture, concurrency, naming, testing,
   modularization, and quality invariants.
2. Treat `.swiftformat` and `.swiftlint.yml` as the executable style contract.
3. Follow the active specification and accepted ADRs where they narrow a design.
4. Prefer the established local pattern when multiple styles satisfy these
   authorities.

## Write safe Swift

- Prefer immutable values and the narrowest useful access level.
- Do not use force unwraps, `try!`, forced casts, implicitly unwrapped optionals,
  or `fatalError` as ordinary control flow, including in tests and fixtures.
- In Swift Testing, unwrap required values with `try #require`. At untrusted
  boundaries, validate and return or throw an explicit error.
- A genuinely necessary forced operation requires a narrow inline justification
  and the smallest possible SwiftLint suppression. Never disable a rule broadly.
- Make invalid business states hard to represent and keep unknown, failure, and
  valid negative outcomes distinct.
- Use minimal imports and remove dead code, placeholders, and stale comments.

## Design APIs and names

- Optimize names for clarity at the call site.
- Name protocols for their capability or role without a `Protocol` suffix.
- Name concrete types for behavior or technology without `Impl`,
  `Implementation`, or type-kind suffixes.
- Introduce a protocol only for a real boundary, substitutability requirement,
  or current polymorphic consumer; do not create speculative abstractions.
- Keep protocol conformances in focused extensions when that improves cohesion,
  without forcing unrelated private members into extensions.
- Prefer methods associated with the type that owns the behavior; use free
  functions for genuinely type-independent operations.

## Preserve architecture and concurrency

- Preserve `Presentation -> Domain <- Data` and wire concrete dependencies only
  in app composition.
- Keep Domain free of SwiftUI, networking, persistence, and Data DTOs.
- Keep observable UI state on `MainActor`; use immutable `Sendable` values across
  asynchronous boundaries.
- Give mutable shared state one explicit actor or lock-protected owner.
- Preserve cancellation and stale-response protection. Do not introduce Combine
  or unchecked concurrency escape hatches.

## Write maintainable tests

- Use Swift Testing for new unit tests unless extending an existing XCTest-only
  surface is necessary.
- Prefer `#expect` and `try #require`; never make malformed fixtures crash the
  test process.
- Test observable outcomes and meaningful boundaries rather than private call
  sequences.
- Use deterministic fakes or mocks. Do not depend on live network responses.

## Complete the change

1. Review the full diff for forced operations, lint suppressions, dead code,
   accidental API exposure, and unrelated formatting.
2. Run focused tests while iterating.
3. Run the repository formatting and lint gates; fix violations rather than
   weakening the rules.
4. Follow the implementation or review skill for final delivery evidence.
