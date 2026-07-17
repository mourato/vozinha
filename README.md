# Vozinha for macOS

A native macOS app that detects video-call meetings, captures system audio, and transcribes locally using on-device AI models via the [FluidAudio SDK](https://github.com/FluidInference/FluidAudio).

## Key features

- System audio capture via ScreenCaptureKit (macOS 15+)
- Auto-detection for Google Meet, Microsoft Teams, Slack, Zoom
- Local transcription with Apple Neural Engine acceleration (Apple Silicon recommended)
- Configurable global shortcut to start/stop recording
- Optional AI post-processing (Settings)
- File import (mp3, m4a, wav)
- Centralized logging with `os.log`

## Requirements

- macOS 15.0+ (Sequoia or later)
- Apple Silicon (recommended)
- Xcode 16.0+ (development)
- Xcode command line tools selected (`xcode-select -p`)
- Homebrew (for `make setup`)

## Documentation

- Architecture and operational standards: `AGENTS.md` + `.agents/skills/architecture/SKILL.md`
- Known limitations backlog: GitHub issues labeled `known-limitation`
- Installation, permissions, and troubleshooting: this README

## Development

This project is **CLI-first** (for parity with CI), with Xcode supported for debugging and UI iteration.

```bash
git clone https://github.com/mourato/vozinha.git
cd vozinha
./scripts/setup-dev-environment.sh
make build
make run
make dmg
```

`./scripts/setup-dev-environment.sh` verifies the local developer toolchain, including `make`, installs Homebrew-managed tools (`swiftlint`, `swiftformat`), and configures tracked Git hooks (`core.hooksPath=scripts/hooks`). After `make` is available, `make setup` runs the same script. SwiftPM dependencies resolve automatically during build. Local AI model assets may download on first use.

Use `make help` to print the current target list from the `Makefile`.

### Agent delivery loop

For compact, auditable iteration:

```bash
make scope-check-agent ARGS="--dry-run --base main"  # preview when the gate is unclear
make build-agent                                      # or the smallest relevant check
make lint-strict-agent                                # end of task when Swift changed
make validate-agent ARGS="--lane auto --base main --agent"  # end of task when behavior changed
```

The pre-commit hook applies SwiftFormat and SwiftLint autofix to staged Swift files (re-staging fixes) and does not run tests. The pre-push hook does not run build or test validation — end-of-task development owns `validate-agent` (auto/Full as lane requires). `SKIP_LINT=1` and `SKIP_TESTS=1` are explicit emergency bypasses for local validation commands.

### Make targets

#### Build

| Target | Description |
|--------|-------------|
| `make build` | Alias for `make build-debug`. |
| `make build-debug` | Build the app in Debug configuration. |
| `make build-release` | Build the app in Release configuration. |
| `make build-agent` | Build Debug with compact agent-oriented output. |
| `make build-test` | Run the standard build and test sequence. |
| `make xcodebuild-safe` | Run the canonical wrapped `xcodebuild` command for this repo. |

#### Test and benchmarks

| Target | Description |
|--------|-------------|
| `make test` | Run the fast local development test suite. |
| `make test-agent` | Run tests with compact agent-oriented output. |
| `make test-swift` | Run tests with `swift test` for a faster non-Xcode path. |
| `make test-verbose` | Run tests with verbose output. |
| `make test-strict` | Run tests with strict concurrency checking enabled. |
| `make test-ci-strict` | Run the strict Xcode parity gate. |
| `make scope-check` | Run scoped validation (targeted checks + automatic escalation to full gate when needed). |
| `make scope-check-agent` | Run scoped validation in compact agent mode. |
| `make benchmark-summary` | Run the summary benchmark gate in report-only mode. |
| `make benchmark-summary-agent` | Run the summary benchmark in compact agent mode. |

#### Quality and verification

| Target | Description |
|--------|-------------|
| `make lint` | Run lint checks. Use `FIX=1 make lint` to auto-fix first. |
| `make lint-agent` | Run lint with compact agent-oriented output. |
| `make lint-fix` | Apply SwiftFormat and SwiftLint autofixes. |
| `make arch-check` | Validate architecture boundary rules. |
| `make preview-check` | Verify SwiftUI preview coverage. |
| `make preflight` | Run the full preflight script (build, test, lint, benchmark). |
| `make preflight-fast` | Run the faster preflight variant. |
| `make preflight-agent` | Run preflight with compact agent-oriented output. |
| `make preflight-agent-fast` | Run the fast preflight variant in agent mode. |
| `make format` | Format source with SwiftFormat. |
| `make health` | Run the repository code health check. |

#### Run and distribution

| Target | Description |
|--------|-------------|
| `make run` | Build Debug and open the app. |
| `make run-release` | Build Release and open the app. |
| `make dmg` | Build Release and create `dist/Vozinha.dmg`, prompting for automatic, self-signed, or ad-hoc signing. |
| `make setup-self-signed-cert` | Create or import the local self-signed signing certificate. |
| `make new-release` | Create a GitHub release interactively with generated notes. |

#### Profiling

| Target | Description |
|--------|-------------|
| `make profile` | Run the full profiling suite. |
| `make profile-report` | Run profiling and export summary metrics. |
| `make profile-cpu` | Run CPU profiling with Time Profiler. |
| `make profile-memory` | Run memory profiling with Allocations. |
| `make profile-animation` | Run Core Animation profiling. |
| `make profile-animation-report` | Run animation profiling and export metrics. |

#### Maintenance and CI

| Target | Description |
|--------|-------------|
| `make clean` | Remove build and distribution artifacts. |
| `make setup` | Install local development dependencies (SwiftLint, SwiftFormat) and configure Git hooks. |
| `make ci-build` | Run the CI build sequence: architecture checks, lint, tests, and release build. |
| `make ci-test` | Run the CI test path. |
| `make ci-release-parity` | Run the local Sparkle release parity gate in dry-run mode. |
| `make ci-release-parity-self-signed` | Run the signed local Sparkle parity flow and generate the appcast. |
| `make deliverable-gate` | Run `build-test`, `lint`, and `ci-release-parity` together. |

#### Documentation

| Target | Description |
|--------|-------------|
| `make docs` | Build the DocC static documentation output into `.agents/docs/api`. |
| `make docs-preview` | Preview DocC documentation locally. |
| `make docs-clean` | Remove generated documentation artifacts. |

### Before push/release

Run the deliverable gate to reduce CI surprises:

```bash
make deliverable-gate
```

This includes `make lint`, `make build-test`, and `make ci-release-parity` (lint runs first as a fast-fail gate).

To enforce strict Xcode pin matching in automated runs:

```bash
MA_CI_PARITY_STRICT_XCODE_VERSION=1 make ci-release-parity
```

### Canonical xcodebuild usage

Use the project wrapper (or pass equivalent flags) when invoking `xcodebuild` directly:

```bash
./scripts/xcodebuild-safe.sh
```

Equivalent raw command:

```bash
xcodebuild -project MeetingAssistant.xcodeproj -scheme MeetingAssistant -configuration Debug -destination 'platform=macOS' build
```

Avoid running bare `xcodebuild build` in this repository; it can trigger SwiftPM transitive-module resolution failures.

### B2 architecture layout

The package uses a modular split and an aggregation target:

- `MeetingAssistantCoreCommon` (shared utilities/resources)
- `MeetingAssistantCoreDomain` (entities/protocols/use cases)
- `MeetingAssistantCoreInfrastructure` (integration services)
- `MeetingAssistantCoreData` (persistence repositories)
- `MeetingAssistantCoreAudio` (capture/buffering/worker pipeline)
- `MeetingAssistantCoreAI` (transcription/post-processing/rendering)
- `MeetingAssistantCoreUI` (view models/coordinators/views)
- `MeetingAssistantCore` (compatibility export layer)

Physical source directories under `Packages/MeetingAssistantCore/Sources/` use the short names `Common`, `Domain`, `Infrastructure`, `Data`, `Audio`, `AI`, `UI`, `Core`, `Mocking`, and `MockingMacros`.

Guideline: import only required modules in each file, and expose cross-module APIs intentionally through access control and domain protocols.

### Language standard

- Documentation is maintained in English.
- Code comments are maintained in English.
- UI strings must use localization keys (`"key".localized`), not hardcoded literals.

### Branch workflow (mandatory)

All changes (code or docs) must be done in a dedicated Git branch in the current checkout.

```bash
git checkout main
git pull --ff-only
git checkout -b <branch-name>
```

See `AGENTS.md` for the full workflow and project standards.

## Permissions

The app will ask for permissions in **System Settings → Privacy & Security**:

| Permission | Why it is needed |
|-----------|------------------|
| Screen Recording | System audio capture via ScreenCaptureKit |
| Microphone | Fallback audio capture |
| Accessibility | Global shortcuts and Assistant actions |

## Local self-signed update flow (no Developer ID)

If you cannot use Apple Developer ID, use a stable self-signed identity so local updates are signed consistently.

```bash
# 1) Create/import local signing certificate (one-time)
make setup-self-signed-cert

# 2) Build DMG for manual installs
# Interactive mode: prompts for automatic, forced self-signed, or forced unsigned/ad-hoc signing
make dmg

# Force self-signed mode without prompting; fails fast if the identity is missing
MA_RELEASE_SIGNING_MODE=self-signed make dmg

# Force unsigned/ad-hoc mode without prompting
MA_RELEASE_SIGNING_MODE=adhoc make dmg

# 3) Build signed Sparkle archive + appcast (requires Sparkle private key env)
SPARKLE_PRIVATE_KEY_B64="<base64-pem>" \
make ci-release-parity-self-signed \
  DOWNLOAD_URL_PREFIX="https://github.com/<owner>/<repo>/releases/download/<tag>" \
  RELEASE_TAG="v0.3.4"
```

Notes:
- Keep `CFBundleIdentifier` unchanged between versions.
- Keep `MA_RELEASE_CODE_SIGN_IDENTITY` stable if you customize the certificate name.
- `make dmg` builds the Release app, packages it, signs the DMG, and writes `dist/Vozinha.dmg`.
- `make dmg` now prompts for signing mode. The default choice is automatic detection: if the exact configured identity is found in keychain, the DMG is self-signed; otherwise it falls back to unsigned/ad-hoc.
- Use `MA_RELEASE_SIGNING_MODE=adhoc make dmg` or `MA_RELEASE_SIGNING_MODE=self-signed make dmg` to skip the prompt and force a specific mode.
- Install by replacing the existing app in `/Applications` to maximize permission persistence.
- Sparkle signing key can come from `SPARKLE_PRIVATE_KEY_B64` / `SPARKLE_PRIVATE_KEY` env, or from Sparkle's default Keychain account (`ed25519`).

## Troubleshooting

### The model takes a long time to load

On first use, FluidAudio may download and prepare the model(s). This can take a few minutes depending on your network.

### Audio capture does not work

- Check **Privacy & Security → Screen Recording** and ensure Vozinha is enabled.
- If you rebuilt/reinstalled the app, macOS may require re-granting permission.

## License

MIT
