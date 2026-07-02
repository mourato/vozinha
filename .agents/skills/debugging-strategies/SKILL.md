---
name: debugging-strategies
description: This skill should be used when the user asks to "debug a bug", "investigate a crash", "analyze flaky behavior", or "trace an unknown root cause" across subsystems.
---

# Debugging Strategies

## Role

Use this skill as the canonical owner for cross-cutting debugging methodology in Prisma.

- Own investigation structure when the root cause is still unknown.
- Focus on evidence gathering, hypothesis testing, and narrowing scope before subsystem-specific fixes.
- Delegate known bottlenecks or specialized runtime problems to the matching domain owner.

## Scope Boundaries

- Use this skill for cross-cutting investigation methodology when root cause is unknown.
- Use `../swiftui-patterns/SKILL.md` once a SwiftUI rendering/update/layout issue has a clear structural fix.
- Use `../audio-realtime/SKILL.md` for render-thread and low-latency audio defects once the failing path is confirmed.
- Use `../swift-concurrency-expert/SKILL.md` for concrete actor-isolation or `Sendable` diagnostics.

## When to Use

Use this skill when the root cause is still unknown and the first job is to narrow the problem safely:

- crash investigation
- flaky behavior
- regressions after recent changes
- performance symptoms before the bottleneck is confirmed

## Investigation Workflow

1. Reproduce the issue with exact steps, state, and environment.
2. Reduce the scope to one subsystem, transition, or invariant.
3. Compare working vs broken paths.
4. Add the smallest useful instrumentation.
5. Validate or kill one hypothesis at a time.
6. Route to the subsystem owner once the failure surface is known.

## Core Principles

### Reproduction first

- Write the failing path down before changing code.
- Separate first-launch, warm-launch, background/foreground, and reopen behavior when relevant.
- Prefer the smallest deterministic repro over broad “seems broken” notes.

### Compare states, not stories

- Check what changed in code, persisted data, permissions, feature flags, and app lifecycle.
- Compare working vs broken state with concrete evidence: logs, timestamps, actor hops, menu state, persisted records, or view transitions.
- Do not trust memory when `git`, logs, or current code can answer it.

### Instrument surgically

- Add logging around boundaries, not everywhere.
- Prefer existing diagnostics surfaces and stable log keys.
- Remove speculative instrumentation once the root cause is understood.

### Preserve changed-path proof

- Name the focused tests, builds, or manual flows that prove the failing path.
- If full gates fail, distinguish changed-path failures from existing baseline noise.

## Prisma-Specific Checklist

Before editing code, check:

- startup vs reopen behavior
- observer or monitor teardown symmetry
- actor ownership of UI-facing state
- persisted settings or migration shape
- feature flags, permissions, and capture mode differences
- SwiftUI row identity, derived state in `body`, and repeated formatting/filtering when UI jank is reported

### Useful local commands

```bash
git log --stat -- <path>
git diff -- <path>
make scope-check
make build-agent
./scripts/run-tests.sh --suite dev --test <TestName>
```

## Evidence Notes

- Record one short note per disproved hypothesis.
- When the fix is found, document the invariant that was violated.
- If the issue turns out to be subsystem-specific, stop expanding this skill and move to the subsystem owner.

## Related Skills

- `../audio-realtime/SKILL.md`
- `../swift-concurrency-expert/SKILL.md`
- `../swiftui-patterns/SKILL.md`
- `../observability-diagnostics/SKILL.md`

## References

- **[assets/debugging-checklist.md](assets/debugging-checklist.md)**: Quick investigation checklist
- **[assets/common-bugs.md](assets/common-bugs.md)**: Common failure patterns in this repo shape
- **[references/debugging-tools-guide.md](references/debugging-tools-guide.md)**: Tooling and capture tips
- **[references/performance-profiling.md](references/performance-profiling.md)**: Performance investigation guidance
- **[references/production-debugging.md](references/production-debugging.md)**: Production-safe debugging habits
