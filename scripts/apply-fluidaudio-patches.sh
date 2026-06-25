#!/bin/bash
# =============================================================================
# apply-fluidaudio-patches.sh - Idempotent local patches for FluidAudio checkouts
# =============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

patch_checkout() {
    local checkout_root="$1"
    local asr_manager_path
    local streaming_asr_manager_path
    local granite_models_path="${checkout_root}/Sources/FluidAudio/ASR/Granite/GraniteAsrModels.swift"
    local granite_plus_models_path="${checkout_root}/Sources/FluidAudio/ASR/Granite/GranitePlusAsrModels.swift"
    local nemotron_manager_path="${checkout_root}/Sources/FluidAudio/ASR/Parakeet/Streaming/Nemotron/NemotronStreamingAsrManager.swift"
    local kokoro_memory_path="${checkout_root}/Sources/FluidAudio/TTS/Kokoro/Pipeline/Synthesize/KokoroSynthesizer+Memory.swift"

    if [ ! -d "${checkout_root}/Sources/FluidAudio" ]; then
        return 0
    fi

    if [ -f "${checkout_root}/Sources/FluidAudio/ASR/AsrManager.swift" ]; then
        asr_manager_path="${checkout_root}/Sources/FluidAudio/ASR/AsrManager.swift"
    else
        asr_manager_path="${checkout_root}/Sources/FluidAudio/ASR/Parakeet/AsrManager.swift"
    fi

    if [ -f "${checkout_root}/Sources/FluidAudio/ASR/Streaming/StreamingAsrManager.swift" ]; then
        streaming_asr_manager_path="${checkout_root}/Sources/FluidAudio/ASR/Streaming/StreamingAsrManager.swift"
    else
        streaming_asr_manager_path="${checkout_root}/Sources/FluidAudio/ASR/Parakeet/SlidingWindow/SlidingWindowAsrManager.swift"
    fi

    chmod u+w "${asr_manager_path}" "${streaming_asr_manager_path}" "${granite_models_path}" \
        "${granite_plus_models_path}" "${nemotron_manager_path}" "${kokoro_memory_path}" 2>/dev/null || true

    if [ -f "${asr_manager_path}" ] && grep -q "public final class AsrManager" "${asr_manager_path}" \
        && ! grep -q "public final class AsrManager: @unchecked Sendable {" "${asr_manager_path}"; then
        perl -0pi -e 's/public final class AsrManager(?::\s+Sendable)? \{/public final class AsrManager: \@unchecked Sendable {/g' "${asr_manager_path}"
    fi

    if [ -f "${asr_manager_path}" ] && grep -q "public final class AsrManager" "${asr_manager_path}" \
        && ! grep -q "public final class AsrManager: @unchecked Sendable {" "${asr_manager_path}"; then
        echo "Failed to patch FluidAudio checkout at ${checkout_root}" >&2
        exit 1
    fi

    if [ -f "${streaming_asr_manager_path}" ]; then
        perl -0pi -e 's/nonisolated\(unsafe\) private var asrManager: AsrManager\?/private var asrManager: AsrManager?/g' "${streaming_asr_manager_path}"
        perl -0pi -e 's/nonisolated\(unsafe\) private var ctcSpotter: CtcKeywordSpotter\?/private var ctcSpotter: CtcKeywordSpotter?/g' "${streaming_asr_manager_path}"
        perl -0pi -e 's/nonisolated\(unsafe\) private var vocabularyRescorer: VocabularyRescorer\?/private var vocabularyRescorer: VocabularyRescorer?/g' "${streaming_asr_manager_path}"

        if grep -q "nonisolated(unsafe) private var asrManager: AsrManager?" "${streaming_asr_manager_path}"; then
            echo "Failed to patch StreamingAsrManager concurrency state at ${checkout_root}" >&2
            exit 1
        fi
    fi

    if [ -f "${granite_models_path}" ]; then
        perl -0pi -e 's/public struct GraniteAsrModels \{/public struct GraniteAsrModels: \@unchecked Sendable {/g' "${granite_models_path}"
        if ! grep -q "public struct GraniteAsrModels: @unchecked Sendable {" "${granite_models_path}"; then
            echo "Failed to patch GraniteAsrModels Sendable conformance at ${checkout_root}" >&2
            exit 1
        fi
    fi

    if [ -f "${granite_plus_models_path}" ]; then
        perl -0pi -e 's/public struct GranitePlusAsrModels \{/public struct GranitePlusAsrModels: \@unchecked Sendable {/g' "${granite_plus_models_path}"
        if ! grep -q "public struct GranitePlusAsrModels: @unchecked Sendable {" "${granite_plus_models_path}"; then
            echo "Failed to patch GranitePlusAsrModels Sendable conformance at ${checkout_root}" >&2
            exit 1
        fi
    fi

    if [ -f "${nemotron_manager_path}" ]; then
        perl -0pi -e 's/\n\s*case \.int8:\n\s*bytesPerElement = MemoryLayout<Int8>\.stride//g' "${nemotron_manager_path}"
        if grep -q "case \\.int8:" "${nemotron_manager_path}"; then
            echo "Failed to patch NemotronStreamingAsrManager int8 case at ${checkout_root}" >&2
            exit 1
        fi
    fi

    if [ -f "${kokoro_memory_path}" ]; then
        perl -0pi -e 's/\s*#if canImport\(FoundationModels\).*?#endif/\n            @unknown default:\n                memset(array.dataPointer, 0, elementCount * MemoryLayout<Float>.stride)/sg' "${kokoro_memory_path}"
        if grep -q "case \\.int8:" "${kokoro_memory_path}"; then
            echo "Failed to patch KokoroSynthesizer memory int8 case at ${checkout_root}" >&2
            exit 1
        fi
    fi
}

checkout_roots=("$@")
if [ "${#checkout_roots[@]}" -eq 0 ]; then
    checkout_roots=(
        "${PROJECT_DIR}/Packages/MeetingAssistantCore/.build/checkouts/FluidAudio"
        "${PROJECT_DIR}/.xcode-build/SourcePackages/checkouts/FluidAudio"
        "${PROJECT_DIR}/.xcode-build-tests/SourcePackages/checkouts/FluidAudio"
        "${PROJECT_DIR}/.xcode-build-ci-parity/SourcePackages/checkouts/FluidAudio"
        "${PROJECT_DIR}/.xcode-build-release-parity/SourcePackages/checkouts/FluidAudio"
        "${PROJECT_DIR}/build/DerivedData/SourcePackages/checkouts/FluidAudio"
    )

    if [ -d "${HOME}/Library/Developer/Xcode/DerivedData" ]; then
        while IFS= read -r derived_checkout; do
            checkout_roots+=("${derived_checkout}")
        done < <(
            find "${HOME}/Library/Developer/Xcode/DerivedData" \
                -type d \
                -path '*/SourcePackages/checkouts/FluidAudio' \
                2>/dev/null
        )
    fi
fi

for checkout_root in "${checkout_roots[@]}"; do
    patch_checkout "${checkout_root}"
done
