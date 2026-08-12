#!/bin/bash
# =============================================================================
# apply-fluidaudio-patches.sh - Idempotent local patches for FluidAudio checkouts
# =============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

apply_perl_patch_if_changed() {
    local file_path="$1"
    local expression="$2"
    local temp_path

    temp_path="$(mktemp "${file_path}.tmp.XXXXXX")"
    cp -p "${file_path}" "${temp_path}"
    perl -0pi -e "${expression}" "${temp_path}"

    if cmp -s "${file_path}" "${temp_path}"; then
        rm -f "${temp_path}"
    else
        mv "${temp_path}" "${file_path}"
    fi
}

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
        apply_perl_patch_if_changed "${asr_manager_path}" 's/public final class AsrManager(?::\s+Sendable)? \{/public final class AsrManager: \@unchecked Sendable {/g'
    fi

    if [ -f "${asr_manager_path}" ] && grep -q "public final class AsrManager" "${asr_manager_path}" \
        && ! grep -q "public final class AsrManager: @unchecked Sendable {" "${asr_manager_path}"; then
        echo "Failed to patch FluidAudio checkout at ${checkout_root}" >&2
        exit 1
    fi

    if [ -f "${streaming_asr_manager_path}" ]; then
        apply_perl_patch_if_changed "${streaming_asr_manager_path}" 's/nonisolated\(unsafe\) private var asrManager: AsrManager\?/private var asrManager: AsrManager?/g'
        apply_perl_patch_if_changed "${streaming_asr_manager_path}" 's/nonisolated\(unsafe\) private var ctcSpotter: CtcKeywordSpotter\?/private var ctcSpotter: CtcKeywordSpotter?/g'
        apply_perl_patch_if_changed "${streaming_asr_manager_path}" 's/nonisolated\(unsafe\) private var vocabularyRescorer: VocabularyRescorer\?/private var vocabularyRescorer: VocabularyRescorer?/g'

        if grep -q "nonisolated(unsafe) private var asrManager: AsrManager?" "${streaming_asr_manager_path}"; then
            echo "Failed to patch StreamingAsrManager concurrency state at ${checkout_root}" >&2
            exit 1
        fi
    fi

    if [ -f "${granite_models_path}" ]; then
        apply_perl_patch_if_changed "${granite_models_path}" 's/public struct GraniteAsrModels \{/public struct GraniteAsrModels: \@unchecked Sendable {/g'
        if ! grep -q "public struct GraniteAsrModels: @unchecked Sendable {" "${granite_models_path}"; then
            echo "Failed to patch GraniteAsrModels Sendable conformance at ${checkout_root}" >&2
            exit 1
        fi
    fi

    if [ -f "${granite_plus_models_path}" ]; then
        apply_perl_patch_if_changed "${granite_plus_models_path}" 's/public struct GranitePlusAsrModels \{/public struct GranitePlusAsrModels: \@unchecked Sendable {/g'
        if ! grep -q "public struct GranitePlusAsrModels: @unchecked Sendable {" "${granite_plus_models_path}"; then
            echo "Failed to patch GranitePlusAsrModels Sendable conformance at ${checkout_root}" >&2
            exit 1
        fi
    fi

    if [ -f "${nemotron_manager_path}" ]; then
        apply_perl_patch_if_changed "${nemotron_manager_path}" 's/\n\s*case \.int8:\n\s*bytesPerElement = MemoryLayout<Int8>\.stride//g'
        if grep -q "case \\.int8:" "${nemotron_manager_path}"; then
            echo "Failed to patch NemotronStreamingAsrManager int8 case at ${checkout_root}" >&2
            exit 1
        fi
    fi

    if [ -f "${kokoro_memory_path}" ]; then
        apply_perl_patch_if_changed "${kokoro_memory_path}" 's/\s*#if canImport\(FoundationModels\).*?#endif/\n            @unknown default:\n                memset(array.dataPointer, 0, elementCount * MemoryLayout<Float>.stride)/sg'
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
