# Common Bug Patterns

Use this checklist when the symptom is real but the root cause is still unclear.

## State and Lifecycle

- Initialization order differs between first launch and warm launch.
- Observer registration and teardown are asymmetric.
- A cached value survives longer than the UI flow expects.
- A cancellation path leaves the system in a partially-updated state.

## Concurrency and Timing

- Two async operations race to update the same state.
- A callback crosses actor boundaries without an explicit ownership rule.
- Work is scheduled on the main actor later than the UI assumes.
- Timeout, debounce, or retry logic changes event ordering under load.

## Data and Persistence

- Migration logic handles the latest schema but not older persisted data.
- A repository writes one representation and reads another.
- Test fixtures do not reflect production data shape or volume.
- A fallback path silently masks a corrupt or incomplete record.

## Environment and Configuration

- Debug and release builds use different entitlement, path, or flag behavior.
- A script, Make target, or workflow changed without matching documentation updates.
- A local-only file, credential, or permission state is required but undocumented.
- Toolchain differences change compiler or package-resolution behavior.

## UI and Interaction

- Focus restoration differs between close, reopen, and background transitions.
- Accessibility or keyboard behavior diverges from pointer-driven behavior.
- Preview-only guards hide side effects that still run in production.
- View state is derived in more than one place and drifts over time.
