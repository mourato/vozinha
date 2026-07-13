# Makefile for Prisma - CLI-first development workflow
# =============================================================================
# This Makefile provides common development commands for the Prisma
# project. All commands use xcodebuild CLI tools for maximum compatibility
# with CI/CD pipelines and headless environments.
# =============================================================================

.PHONY: help build build-debug build-release build-agent build-test build-test-strict xcodebuild-safe test test-agent test-full test-full-agent test-smoke test-perf test-sensitive test-appkit test-parity test-parity-agent test-swift test-verbose test-strict test-ci-strict scope-check scope-check-agent benchmark-summary benchmark-summary-agent lint lint-agent lint-strict lint-strict-agent lint-fix arch-check preview-check guidance-check preflight preflight-fast preflight-agent preflight-agent-fast clean run run-release dmg setup-self-signed-cert setup format health ci-build ci-test ci-release-parity ci-release-parity-self-signed deliverable-gate docs docs-preview docs-clean profile profile-report profile-cpu profile-memory profile-animation profile-animation-report

# Default target
help:
	@echo "$(APP_PRODUCT_NAME) Development Commands"
	@echo "===================================="
	@echo ""
	@echo "Build Commands:"
	@echo "  make build          - Build debug version (default)"
	@echo "  make build-debug    - Build debug version explicitly"
	@echo "  make build-release  - Build release version"
	@echo "  make build-agent    - Build debug with compact machine-readable output"
	@echo "  make build-test     - Run build + tests in sequence (fast default, strict in CI)"
	@echo "  make build-test-strict - Run build + tests in strict xcode mode"
	@echo "  make xcodebuild-safe - Build via canonical direct xcodebuild wrapper"
	@echo ""
	@echo "Test Commands:"
	@echo "  make test           - Run fast local dev suite (swift test, parallel)"
	@echo "  make test-agent     - Run fast local dev suite in compact mode"
	@echo "  make test-full      - Run broad swift-test suite for preflight/local gates"
	@echo "  make test-full-agent - Run broad swift-test suite in compact mode"
	@echo "  make test-smoke     - Run curated smoke suite"
	@echo "  make test-perf      - Run isolated performance tests"
	@echo "  make test-sensitive - Run isolated sensitive subsystem tests"
	@echo "  make test-appkit    - Run isolated AppKit lifecycle tests"
	@echo "  make test-parity    - Run xcodebuild parity tests"
	@echo "  make test-parity-agent - Run xcodebuild parity tests in compact mode"
	@echo "  make test-swift     - Alias of make test-full"
	@echo "  make test-verbose   - Run tests with verbose output"
	@echo "  make test-strict    - Run tests with strict concurrency checking"
	@echo "  make test-ci-strict - Run strict xcodebuild parity gate"
	@echo "  make scope-check    - Run scoped validation (targeted tests + smart escalation)"
	@echo "  make scope-check-agent - Run scoped validation in compact agent mode"
	@echo "  make benchmark-summary - Run summary benchmark gate in report-only mode"
	@echo "  make benchmark-summary-agent - Run summary benchmark in compact mode"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint           - Run linting checks (use FIX=1 to auto-fix first)"
	@echo "  make lint-agent     - Run lint with compact machine-readable output"
	@echo "  make lint-strict    - Run lint with strict error handling"
	@echo "  make lint-strict-agent - Run strict lint with compact output"
	@echo "  make lint-fix       - Auto-fix linting issues"
	@echo "  make arch-check     - Run architecture boundary checks"
	@echo "  make preview-check  - Verify all SwiftUI views have previews"
	@echo "  make guidance-check - Validate AGENTS/skills/docs links and make target references"
	@echo "  make preflight      - Run preflight script (build + test + lint + benchmark)"
	@echo "  make preflight-fast - Run fast preflight (lint + build + test)"
	@echo "  make preflight-agent - Run preflight in compact machine-readable mode"
	@echo "  make preflight-agent-fast - Run fast preflight in compact machine-readable mode"
	@echo "  make health         - Run comprehensive code health check"
	@echo ""
	@echo "Run Commands:"
	@echo "  make run            - Build and run debug version"
	@echo "  make run-release    - Build and run release version"
	@echo ""
	@echo "Distribution:"
	@echo "  make dmg            - Create DMG installer (prompts for auto/self-signed/adhoc at start)"
	@echo "  make setup-self-signed-cert - Create/import local code-signing cert"
	@echo "  make new-release    - Create a new GitHub release interactively"
	@echo ""
	@echo "Performance Profiling:"
	@echo "  make profile        - Run all performance profiling (CPU, Memory, Animation)"
	@echo "  make profile-report - Run profiling + export summary metrics"
	@echo "  make profile-cpu    - Profile CPU usage with Time Profiler"
	@echo "  make profile-memory - Profile memory usage with Allocations"
	@echo "  make profile-animation - Profile Core Animation performance"
	@echo "  make profile-animation-report - Profile animation and export metrics"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make setup          - Verify toolchain and install development dependencies"
	@echo ""
	@echo "CI/CD Commands:"
	@echo "  make ci-build       - Full CI build (lint + test + build-release)"
	@echo "  make ci-test        - CI test run (no user interaction)"
	@echo "  make ci-release-parity - Run local parity gate for Sparkle release build/archive"
	@echo "  make ci-release-parity-self-signed - Run local signed Sparkle parity (build+appcast)"
	@echo "  make deliverable-gate - Run build-test + lint + ci-release-parity"
	@echo ""
	@echo "Documentation:"
	@echo "  make docs           - Build DocC documentation"
	@echo "  make docs-preview   - Preview documentation locally"
	@echo "  make docs-clean     - Clean documentation artifacts"

# Configuration
PROJECT_DIR = $(shell pwd)
IDENTITY_SCRIPT = $(PROJECT_DIR)/scripts/config/app_identity.sh
APP_SCHEME = $(shell . "$(IDENTITY_SCRIPT)"; printf "%s" "$$APP_SCHEME")
APP_PRODUCT_NAME = $(shell . "$(IDENTITY_SCRIPT)"; printf "%s" "$$APP_PRODUCT_NAME")
XCODEPROJ_NAME = $(shell . "$(IDENTITY_SCRIPT)"; printf "%s" "$$XCODEPROJ_NAME")
XCODEPROJ = $(PROJECT_DIR)/$(XCODEPROJ_NAME)
DERIVED_DATA = $(PROJECT_DIR)/.xcode-build
DIST_DIR = $(PROJECT_DIR)/dist
AGENT_LOG_DIR ?= /tmp/ma-agent

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m

# Build Commands
build: build-debug

build-debug:
	@./scripts/run-build.sh --configuration Debug

build-release:
	@./scripts/run-build.sh --configuration Release

build-agent:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/run-build.sh --configuration Debug --agent

build-test:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/run-build-and-test.sh

build-test-strict:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" MA_BUILD_TEST_STRICT_XCODE=1 ./scripts/run-build-and-test.sh

xcodebuild-safe:
	@./scripts/xcodebuild-safe.sh

# Test Commands
test:
	@./scripts/run-tests.sh --suite dev

test-agent:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/run-tests.sh --suite dev --agent

test-full:
	@./scripts/run-tests.sh --suite full

test-full-agent:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/run-tests.sh --suite full --agent

test-smoke:
	@./scripts/run-tests.sh --suite smoke

test-perf:
	@./scripts/run-tests.sh --suite perf

test-sensitive:
	@./scripts/run-tests.sh --suite sensitive

test-appkit:
	@./scripts/run-tests.sh --suite appkit

test-parity:
	@./scripts/run-tests-xcode.sh

test-parity-agent:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/run-tests-xcode.sh --agent

test-swift:
	@echo -e "$(BLUE)Running tests (swift test)...$(NC)"
	@./scripts/run-tests.sh --suite full

test-verbose:
	@echo -e "$(BLUE)Running tests (verbose)...$(NC)"
	@./scripts/run-tests.sh --verbose

test-strict:
	@echo -e "$(BLUE)Running tests (Strict Concurrency)...$(NC)"
	@./scripts/run-tests.sh --strict

test-ci-strict:
	@./scripts/run-tests-xcode.sh --strict-xcode

scope-check:
	@./scripts/scope-check.sh $(ARGS)

scope-check-agent:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/scope-check.sh --agent $(ARGS)

benchmark-summary:
	@./scripts/run-summary-benchmark.sh --report-only

benchmark-summary-agent:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/run-summary-benchmark.sh --report-only --agent

# Code Quality
lint:
	@echo -e "$(BLUE)Running SwiftLint...$(NC)"
	@if [ "$(FIX)" = "1" ] || [ "$(FIX)" = "true" ] || [ "$(FIX)" = "yes" ]; then \
		echo -e "$(YELLOW)Autofix enabled (SwiftFormat + SwiftLint --fix)$(NC)"; \
		./scripts/lint-fix.sh && ./scripts/lint.sh; \
	else \
		./scripts/lint.sh; \
	fi

lint-agent:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/lint.sh --agent

lint-strict:
	@STRICT_LINT=1 ./scripts/lint.sh

lint-strict-agent:
	@STRICT_LINT=1 MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/lint.sh --agent

lint-fix:
	@echo -e "$(BLUE)Auto-fixing lint issues...$(NC)"
	@./scripts/lint-fix.sh

arch-check:
	@echo -e "$(BLUE)Running architecture checks...$(NC)"
	@./scripts/architecture-check.sh

preview-check:
	@echo -e "$(BLUE)Checking SwiftUI preview coverage...$(NC)"
	@./scripts/preview-check.sh

guidance-check:
	@echo -e "$(BLUE)Validating AGENTS/skills/docs guidance...$(NC)"
	@python3 ./scripts/validate-agent-guidance.py

preflight:
	@echo -e "$(BLUE)Running preflight checks...$(NC)"
	@./scripts/preflight.sh

preflight-fast:
	@echo -e "$(BLUE)Running fast preflight checks...$(NC)"
	@./scripts/preflight.sh --fast

preflight-agent:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/preflight.sh --agent

preflight-agent-fast:
	@MA_AGENT_MODE=1 MA_AGENT_LOG_DIR="$(AGENT_LOG_DIR)" ./scripts/preflight.sh --agent --fast

format:
	@echo -e "$(BLUE)Running SwiftFormat...$(NC)"
	@if ! command -v swiftformat &> /dev/null; then \
		echo "❌ SwiftFormat not installed. Install with: brew install swiftformat"; \
		exit 1; \
	fi
	@swiftformat --config .swiftformat App Packages/MeetingAssistantCore/Sources
	@echo -e "$(GREEN)✓ Code formatted$(NC)"

health:
	@echo -e "$(BLUE)Running code health check...$(NC)"
	@./scripts/code-health-check.sh

# Run Commands
run: build-debug
	@echo -e "$(YELLOW)Launching $(APP_PRODUCT_NAME) (Debug)...$(NC)"
	@open "$(DERIVED_DATA)/Build/Products/Debug/$(APP_PRODUCT_NAME).app"

run-release: build-release
	@echo -e "$(YELLOW)Launching $(APP_PRODUCT_NAME) (Release)...$(NC)"
	@open "$(DERIVED_DATA)/Build/Products/Release/$(APP_PRODUCT_NAME).app"

# Distribution
new-release:
	@latest=$$(git describe --tags --abbrev=0 2>/dev/null || echo "None"); \
	echo -e "$(BLUE)Last release was: $$latest$(NC)"; \
	read -p "Enter new release version (e.g., v1.0.1): " version; \
	if [ -z "$$version" ]; then \
		echo -e "$(RED)Error: Version cannot be empty.$(NC)"; \
		exit 1; \
	fi; \
	echo ""; \
	echo -e "$(YELLOW)Creating release $$version with auto-generated notes...$(NC)"; \
	gh release create "$$version" --generate-notes; \
	echo -e "$(GREEN)✓ Successfully created release $$version!$(NC)"

dmg:
	@echo -e "$(BLUE)Creating DMG installer...$(NC)"
	@./scripts/create-dmg.sh --auto-signing

setup-self-signed-cert:
	@./scripts/setup-self-signed-cert.sh

# Maintenance
clean:
	@echo -e "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf "$(DERIVED_DATA)"
	@rm -rf "$(DIST_DIR)"
	@echo -e "$(GREEN)✓ Clean completed$(NC)"

setup:
	@./scripts/setup-dev-environment.sh

# Profiling Commands
profile: build-debug
	@echo -e "$(BLUE)Running performance profiling (all)...$(NC)"
	@./scripts/profile-performance.sh --all

profile-report: build-debug
	@echo -e "$(BLUE)Running performance profiling with report extraction...$(NC)"
	@./scripts/profile-performance.sh --all --report

profile-cpu: build-debug
	@echo -e "$(BLUE)Running CPU profiling...$(NC)"
	@./scripts/profile-performance.sh --cpu

profile-memory: build-debug
	@echo -e "$(BLUE)Running memory profiling...$(NC)"
	@./scripts/profile-performance.sh --memory

profile-animation: build-debug
	@echo -e "$(BLUE)Running animation profiling...$(NC)"
	@./scripts/profile-performance.sh --animation

profile-animation-report: build-debug
	@echo -e "$(BLUE)Running animation profiling with report extraction...$(NC)"
	@./scripts/profile-performance.sh --animation --report


# CI/CD Commands
ci-build: arch-check lint test build-release
	@echo -e "$(GREEN)✓ CI build completed successfully$(NC)"

ci-test: test
	@echo -e "$(GREEN)✓ CI tests completed$(NC)"

ci-release-parity:
	@./scripts/ci-release-parity.sh --mode local --phase build-archive --dry-run 1

ci-release-parity-self-signed:
	@if [ -z "$(DOWNLOAD_URL_PREFIX)" ]; then \
		echo -e "$(RED)Error: set DOWNLOAD_URL_PREFIX for appcast generation.$(NC)"; \
		echo -e "Example: make ci-release-parity-self-signed DOWNLOAD_URL_PREFIX=https://example.com/releases RELEASE_TAG=v0.3.4"; \
		exit 1; \
	fi
	@MA_RELEASE_SIGNING_MODE=self-signed ./scripts/ci-release-parity.sh --mode local --phase build-archive --dry-run 0 $(if $(RELEASE_TAG),--release-tag $(RELEASE_TAG),)
	@MA_RELEASE_SIGNING_MODE=self-signed ./scripts/ci-release-parity.sh --mode local --phase package-appcast --dry-run 0 --archive-path build/$(APP_PRODUCT_NAME).xcarchive --download-url-prefix "$(DOWNLOAD_URL_PREFIX)" $(if $(RELEASE_TAG),--release-tag $(RELEASE_TAG),)

deliverable-gate:
	@$(MAKE) lint
	@$(MAKE) build-test
	@$(MAKE) ci-release-parity
# Documentation
docs:
	@echo -e "$(BLUE)Building DocC documentation...$(NC)"
	@cd Packages/MeetingAssistantCore && \
		swift package --allow-writing-to-directory "$(PROJECT_DIR)/.agents/docs/api" \
		generate-documentation \
		--target MeetingAssistantCore \
		--transform-for-static-hosting \
		--output-path "$(PROJECT_DIR)/.agents/docs/api"
	@echo -e "$(GREEN)✓ Documentation built at .agents/docs/api$(NC)"

docs-preview:
	@echo -e "$(BLUE)Previewing documentation...$(NC)"
	@cd Packages/MeetingAssistantCore && swift package --disable-sandbox preview-documentation --target MeetingAssistantCore

docs-clean:
	@echo -e "$(YELLOW)Cleaning documentation...$(NC)"
	@rm -rf "$(PROJECT_DIR)/.agents/docs/api"
	@echo -e "$(GREEN)✓ Documentation cleaned$(NC)"
