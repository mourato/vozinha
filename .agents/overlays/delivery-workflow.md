---
kind: project-overlay
extends: delivery-workflow
project: vozinha
precedence: project
---

# Vozinha delivery checks

- Product-specific identifiers and commands for Vozinha/Prisma belong in this
  overlay or repository guidance, not in the portable global
  `delivery-workflow` skill.
- `Makefile` is the command authority. Use `make help` before direct script discovery.
- Guidance-only changes use `make guidance-check`; validation-infrastructure changes also require `make workflow-test`.
- `make validate` is the default automatic validation entry; it delegates to
  `validate-agent`. Explicit Fast/Full lanes use `make validate-agent` with
  `ARGS`.
- Changes touching Swift, behavior, audio, concurrency, persistence, security, or cross-module boundaries use that lane policy and retained specialist routing.
- Keep the app local-first: Keychain stores credentials, transcripts and prompts stay out of logs and agent artifacts, and CloudKit synchronization is intentionally absent.
- Report commands, results, risk/lane, review outcome, and known baseline failures in delivery handoffs.
