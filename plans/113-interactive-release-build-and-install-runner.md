# Plan 113: Add an interactive Release-aware build and install runner

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5875628a..HEAD -- scripts/build-and-run.sh scripts/build-release.sh scripts/config/release_signing.sh scripts/create-dmg.sh App/Info.plist App/AppDelegate/AppDelegateLifecycle.swift Makefile README.md .agents/docs/build-and-test.md scripts/tests plans/README.md`.
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. A mismatch
> in identity, signing, lifecycle, or installation behavior is a STOP
> condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: Plan 112 (`plans/112-rebrand-visible-app-name-to-vozinha.md`) being complete, or an explicit confirmation that its `Vozinha` product identity is stable.
- **Category**: dx / tech-debt
- **Planned at**: commit `5875628a`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — the runner, release signing, AppKit shutdown route, and Make/docs contract must agree on one installation workflow.
- **Reviewer required**: yes — the change modifies build/release infrastructure, app lifecycle behavior, code signing, and a destructive filesystem replacement path.
- **Rationale**: The shell portion is bounded, but Release installation can destroy or invalidate the installed app if process shutdown, signing, rollback, or path validation is wrong. The plan also requires a small AppKit integration because the current app intentionally rejects external termination.
- **Escalate when**: the implementation changes bundle IDs, Keychain services, TCC identity, Sparkle update identity, recording persistence, or adds a general-purpose IPC/remote-control surface beyond the single local quit command.

## Why this matters

`make run` currently builds through the canonical pipeline and opens the Debug
bundle, but it does not provide an interactive build/install workflow. The
repository documentation already tells developers to replace the existing app
in `/Applications` to preserve permissions, while Release signing and DMG
creation are separate flows. This plan adds one interactive command that builds
Debug for local iteration and builds, signs, replaces, validates, and relaunches
Release in `/Applications` without duplicating the repository's build logic.

The installation path must be transactional. A failed copy, invalid signature,
or failed launch must not silently leave `/Applications/Vozinha.app` missing or
partially copied. The current app lifecycle also means that a raw `kill` is not a
graceful shutdown: `applicationShouldTerminate` cancels termination unless the
explicit Quit path has set its guard.

## Confirmed behavior contract

These decisions were confirmed by the maintainer during the grill:

- Debug builds never replace the installed app in `/Applications`.
- Only Release builds replace `/Applications/Vozinha.app`.
- Release replacement is automatic once the Release flow is selected; it does
  not require a second manual copy step.
- If the installed app is running, the runner requests the existing graceful
  shutdown path, waits for termination, installs the candidate, validates it,
  and relaunches it.
- A forced termination is never the default. It is an explicit opt-in fallback
  and must be reported clearly.
- The existing technical identity remains stable: bundle ID, XPC identity,
  Keychain service, support/log directories, UserDefaults domains, and Sparkle
  update identity are out of scope.

## Current state

- `Makefile:260-267` implements `make run` and `make run-release` by opening
  `.xcode-build/Build/Products/{Debug,Release}/Vozinha.app` after the build
  target completes. Neither target installs to `/Applications`.
- `scripts/run-build.sh:18-20,118-133` is the canonical Debug/Release build
  entry point. It calls `scripts/xcodebuild-safe.sh` and then stages Rust audio
  kernels. The new runner must call this path instead of invoking raw
  `xcodebuild`.
- `scripts/build-release.sh:53-79` calls `run-build.sh --configuration
  Release`, copies the resulting bundle to `dist/Vozinha.app`, applies the
  configured ad-hoc or self-signed identity, and verifies the signed bundle.
  Its final argument check at `scripts/build-release.sh:96-103` suppresses the
  post-build run prompt for `--ci` and `--no-interactive`.
- `scripts/config/release_signing.sh:4-5,17-50,124-159` owns signing mode,
  identity detection, and self-signed diagnostics. `scripts/create-dmg.sh`
  currently owns a separate interactive signing-mode prompt at lines 50-85;
  that prompt should be extracted or shared rather than copied into the new
  runner.
- `scripts/create-dmg.sh:41-48,121` demonstrates the repository's cleanup-trap
  convention. Its temporary paths are explicit and cleanup is fail-safe.
- `App/AppDelegate/AppDelegateLifecycle.swift:53-64` runs termination cleanup
  and returns `.terminateCancel` unless `isPerformingExplicitQuit` is true.
  `App/AppDelegate/MenuBar.swift:477-502` sets that flag, stops recording
  without transcription, stops monitoring, cleans up the crash reporter, and
  calls `NSApp.terminate(nil)`. A shell `kill` must not be presented as the
  graceful path.
- `README.md:246-253` documents that replacing the existing app in
  `/Applications` is the preferred local update flow for permission continuity.
- The sibling reference's `build_and_run.sh` demonstrates the desired
  interactive Debug/Release selection, explicit `--no-interactive` behavior,
  post-build bundle validation, and install-with-rollback shape. Use it as
  behavior inspiration only; do not copy its hardcoded project/build logic.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Shell syntax | `bash -n scripts/build-and-run.sh scripts/build-release.sh scripts/config/release_signing.sh scripts/create-dmg.sh` | exit 0 |
| Script help | `./scripts/build-and-run.sh --help` | documents interactive and non-interactive modes; no build starts |
| Script fixture tests | `scripts/tests/build-and-run-test.sh` | prints `BUILD_AND_RUN_TEST_STATUS=PASS` |
| Workflow fixtures | `make workflow-test` | exit 0 |
| Guidance | `make guidance-check` | exit 0; Make target references remain valid |
| Debug build | `make build-agent` | Debug build and Rust staging pass |
| Release parity | `make ci-release-parity` | configured local release parity passes, or an existing baseline failure is documented |
| Full validation | `make validate-agent ARGS="--lane full --no-reuse --agent"` | exit 0, or unrelated baseline failures are explicitly recorded |

For manual installation smoke tests, use a disposable override such as
`VOZINHA_APPLICATIONS_DIR` pointing to a temporary fixture directory. Never
point a test at `/Applications` unless the operator explicitly intends to
replace the installed app.

## Scope

### In scope

- `scripts/build-and-run.sh` — new interactive/non-interactive runner.
- `scripts/config/release_signing.sh` — shared signing prompt/selection helper
  if required to remove the duplicate prompt from `create-dmg.sh`.
- `scripts/create-dmg.sh` — consume the shared signing selection helper while
  preserving its current interactive, `--ci`, and `--no-interactive` behavior.
- `scripts/build-release.sh` — only if a small explicit argument/help or
  machine-readable handoff is required; do not duplicate its build/sign logic.
- `App/Info.plist` — register one exact local control URL scheme only if the
  AppKit shutdown route in Step 2 uses it.
- `App/AppDelegate/AppDelegateLifecycle.swift` or a colocated AppDelegate
  lifecycle file — route the exact internal quit URL through the existing
  `quitApp()` graceful path.
- `Makefile` — add `build-and-run` and an explicit non-interactive Release
  install target; preserve `run` and `run-release` semantics.
- `scripts/tests/build-and-run-test.sh` — deterministic shell fixtures for
  parsing, path safety, rollback, and no-prompt behavior.
- `README.md` and `.agents/docs/build-and-test.md` — document the new command,
  Release installation behavior, and safety boundaries.
- `plans/README.md` — update the active ledger after implementation.

### Out of scope

- Debug installation into `/Applications`.
- Replacing or renaming bundle IDs, XPC IDs, Keychain services, support/log
  directories, UserDefaults domains, or Sparkle feed identity.
- Installing to arbitrary paths in production; an override exists only for
  disposable tests and must be validated as an explicit directory.
- Changing recording persistence or transcription behavior during shutdown.
- Adding a general remote-control API. The AppKit control route, if needed,
  must accept only the exact local quit command and exact URL host/path.
- DMG layout, notarization, Sparkle publishing, or GitHub release creation.
- Log streaming, profiling, or a second test runner; those can be separate
  follow-up plans after this installation workflow is stable.

## Steps

### Step 1: Establish the command and identity contract

Create `scripts/build-and-run.sh` with `set -euo pipefail`, repository-root
resolution, generated app identity sourcing, and explicit modes:

- interactive default when stdin/stdout are TTYs and no configuration/action
  flags were supplied;
- `--configuration Debug|Release`;
- `--clean`;
- `--no-interactive`;
- `--force-terminate`;
- `--skip-launch` for build/install verification without relaunching;
- `--applications-dir PATH` or the equivalent test-only environment override;
- `--help`.

Interactive mode should ask for Debug, Release, or Exit, then whether to clean.
Debug should build and open the DerivedData Debug bundle. Release should select
the signing mode, build/sign through the existing Release path, install to
`/Applications/Vozinha.app`, validate, and relaunch unless `--skip-launch` was
given.

Non-interactive mode must never read from stdin. It must require an explicit
configuration and use deterministic defaults. A Release install must fail
closed if signing mode, target path, or process shutdown cannot be resolved.

**Verify**: `bash -n scripts/build-and-run.sh && ./scripts/build-and-run.sh --help` → exit 0, help contains Debug, Release, `--no-interactive`, and `--force-terminate`, and no build starts.

### Step 2: Provide a supported graceful shutdown request

Reuse `AppDelegate.quitApp()` rather than sending a raw signal. Because the
current app has no existing external command route and deliberately cancels
non-explicit termination, add one narrowly scoped local control route:

- register a new `vozinha` URL scheme in `App/Info.plist` only if no existing
  URL scheme conflicts with it;
- handle exactly `vozinha://internal/quit` in the AppDelegate;
- route it to the existing `quitApp()` implementation so active recording is
  stopped without transcription and lifecycle cleanup remains centralized;
- ignore all other hosts, paths, and query values;
- ensure the runner sends the URL only when the exact `Vozinha` process is
  already running, so a stopped app is not launched just to quit.

The runner should wait for the process to exit with a bounded timeout. If the
process does not exit, fail with an actionable diagnostic by default. Allow
`--force-terminate` to request a final exact-process forced termination only
after the graceful attempt has timed out; print that the fallback was used.
The non-interactive path must not force-terminate implicitly.

Add focused AppKit coverage for exact URL acceptance/rejection where the test
target can host it. At minimum, the exact URL behavior must be covered without
starting a real recording or touching user data.

**Verify**: the focused test passes; `make build-agent` compiles the route; and a manual smoke test with an idle installed app confirms that `open vozinha://internal/quit` exits the app through the existing cleanup path.

### Step 3: Reuse release signing and build paths

Refactor the signing-mode prompt currently embedded in `create-dmg.sh` into a
shared function in `scripts/config/release_signing.sh`, preserving its current
auto/self-signed/ad-hoc choices and diagnostics. Update `create-dmg.sh` to use
the shared function without changing its public flags or output contract.

Make the new runner call the existing `build-release.sh --no-interactive`
handoff with the selected signing environment. Do not invoke raw `xcodebuild`,
`codesign`, or Rust staging from the new runner. Debug must call
`run-build.sh --configuration Debug`; Release must consume the signed
`dist/Vozinha.app` produced by `build-release.sh`.

**Verify**: `bash -n` passes for all affected scripts; `make guidance-check`
passes; and an explicit signing mode produces the same signed `dist/Vozinha.app`
and verification behavior as `make dmg`'s existing build phase.

### Step 4: Implement transactional Release replacement

Add an install function with these exact safety rules:

1. Resolve the candidate as `dist/Vozinha.app` and the target as
   `${VOZINHA_APPLICATIONS_DIR:-/Applications}/Vozinha.app`.
2. Reject a missing candidate, a non-directory candidate, a target path that
   is not the exact expected `.app`, or an unsafe root such as `/`.
3. Verify the candidate with `codesign --verify --deep --strict` and inspect
   its bundle identifier before stopping the installed process.
4. Request graceful shutdown and wait. If it times out, stop unless
   `--force-terminate` was explicitly supplied.
5. Copy the candidate to a temporary sibling staging path in the target
   directory, rather than copying directly over the installed bundle.
6. Move the existing target to a uniquely named temporary backup path. If no
   existing app is present, record that rollback has no prior bundle.
7. Move the staged candidate into the exact target path.
8. Verify the installed bundle's signature, bundle identifier, executable, and
   path. If verification fails, remove only the candidate target and restore
   the backup.
9. Relaunch the installed Release app unless `--skip-launch` was supplied and
   verify that the exact process remains alive after a bounded startup wait.
10. Remove the temporary backup and staging paths only after successful
    validation. On any failure, restore the previous bundle and report whether
    rollback succeeded.

Use `ditto`/`mv` with explicit paths and a cleanup trap. Never use a broad glob,
`rm -rf` on the Applications root, or a path assembled from unvalidated user
input. Preserve the existing app path and bundle ID so TCC continuity remains
possible; do not promise that macOS will retain permissions after an ad-hoc
signature change.

**Verify**: run the fixture test with a temporary Applications directory and
fake signed-bundle/copy commands → success replaces only the fixture app,
candidate failure restores the previous fixture app, and unsafe paths fail
before deletion. Then perform one controlled real Release install with the
operator's explicit approval.

### Step 5: Integrate Make and documentation

Add these Make targets while preserving the existing `run` behavior:

```make
build-and-run:
	@./scripts/build-and-run.sh $(ARGS)

install-release:
	@./scripts/build-and-run.sh --no-interactive --configuration Release $(ARGS)
```

The interactive script remains the primary local workflow; `install-release`
is the explicit automation entry point. Do not make `make run-release` replace
`/Applications`, because that would silently change an existing target's
meaning.

Update `make help`, `README.md`, and `.agents/docs/build-and-test.md` with:

- interactive command examples;
- Debug versus Release destination behavior;
- the `/Applications/Vozinha.app` replacement and rollback contract;
- the `--force-terminate` warning;
- the fact that `make dmg` remains the packaging/DMG flow.

**Verify**: `make help` lists both new targets; `make guidance-check` passes;
and every documented command has a matching Make target or script flag.

### Step 6: Test, review, and validate the infrastructure

Extend `scripts/tests/build-and-run-test.sh` using the repository's existing
temporary-fixture style from `scripts/tests/hooks-setup-test.sh` and
`scripts/tests/workflow-fixture-step.sh`. Cover:

- help and invalid argument handling;
- interactive path refusal when no TTY is available;
- non-interactive path never prompting;
- Debug never selecting the Applications target;
- Release candidate path and target path resolution;
- missing candidate and invalid target failures;
- successful replacement in a temporary Applications directory;
- failed candidate verification with rollback;
- graceful shutdown timeout without implicit force;
- explicit force fallback reporting;
- cleanup of stage/backup paths after success and failure.

Run the shell checks and fixture tests first, then `make workflow-test`,
`make guidance-check`, `make build-agent`, `make ci-release-parity`, and one
uncached Full validation. Review the AppKit route and install transaction for
Critical/Medium findings before handoff.

**Verify**: all commands in the Commands table pass, and `git status --short`
contains only the intended in-scope changes plus any pre-existing unrelated
worktree changes.

## Test plan

- Add `scripts/tests/build-and-run-test.sh` with disposable directories and
  command stubs; do not use `/Applications` in automated tests.
- Add route-level coverage for the exact internal quit URL if an AppKit test
  target is available; otherwise document the manual smoke test as a required
  macOS-only gate and stop if the route cannot be tested without launching the
  product.
- Manually test an idle installed Release app, a running Debug app, a Release
  build with an existing installed app, no existing installed app, failed
  candidate validation, and graceful-shutdown timeout.
- Do not collect or print transcripts, prompts, API keys, Keychain values, or
  personal recording paths in test output.

## Done criteria

- [ ] `scripts/build-and-run.sh` supports interactive Debug/Release selection
      and deterministic non-interactive flags.
- [ ] Debug builds never write to `/Applications`.
- [ ] Release builds consume the existing signed `dist/Vozinha.app` path.
- [ ] Release replacement is limited to the exact `Vozinha.app` target.
- [ ] The running app is asked to use the existing graceful shutdown path.
- [ ] Forced termination is opt-in, bounded, and reported.
- [ ] Candidate validation occurs before and after installation.
- [ ] Failed installation restores the previous app when one existed.
- [ ] Successful installation relaunches and verifies the Release process.
- [ ] Existing `make run`, `make run-release`, and `make dmg` semantics remain
      unchanged.
- [ ] Shell fixtures, workflow tests, guidance checks, build, release parity,
      and Full validation pass.
- [ ] No protected identity or persistence identifier changed.
- [ ] `plans/README.md` marks Plan 113 `DONE` only after review and validation.

## STOP conditions

- The current identity contract is not stable because Plan 112 is incomplete
  or changes the bundle/product mapping.
- The exact AppKit quit route cannot be delivered to the already-running app
  without launching a second instance or requiring an unapproved broad IPC
  surface.
- The graceful quit path cannot stop active recording without data loss or
  bypasses the existing `quitApp()` cleanup.
- The implementation needs to use `kill -KILL` by default.
- The install target cannot be proven to be exactly the intended
  `/Applications/Vozinha.app` path.
- Rollback cannot restore the previous app after candidate verification or
  launch failure.
- Release signing requires changing bundle IDs, Keychain identity, Sparkle
  identity, or permission-related technical identifiers.
- Tests need to mutate the real `/Applications` directory or user data.

## Maintenance notes

- Any future change to `APP_PRODUCT_NAME`, bundle ID, signing identity, or
  Release output path must update the runner's identity and install checks.
- Any change to AppDelegate termination guards must re-test the internal quit
  route before Release installation is used.
- Keep the runner's install transaction separate from DMG packaging and Sparkle
  publishing. If permanent rollback/history is desired, create a separate
  decision plan rather than retaining arbitrary old apps in `/Applications`.
- Reviewers should scrutinize every destructive filesystem command, every path
  validation branch, and every process-control fallback.
