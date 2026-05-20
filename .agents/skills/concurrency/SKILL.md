---
name: concurrency
description: This skill should be used when the user asks for conceptual guidance on "async/await", "actors", or "thread-safety patterns" without requesting concrete Swift 6.2 compiler remediation.
---

# Concurrency (Bridge Skill)

## Role

This skill is a lightweight bridge for concurrency-related requests.

- For concrete fixes, compiler diagnostics, actor isolation errors, or Sendable remediation, use **`../swift-concurrency-expert/SKILL.md`**.
- For broad conceptual guidance only, use the canonical references under `../macos-development/references/`.

## Routing

- **Compiler errors / migration / strict concurrency failures** → `swift-concurrency-expert`.
- **General architecture questions without concrete diagnostics** → `macos-development` concurrency references.

## Verification defaults

- Prefer `make test-strict` for concurrency-focused changes.
- Use `./scripts/preflight.sh --strict-concurrency` as an optional comprehensive pass; lane merge gates still follow `quality-assurance` policy.
