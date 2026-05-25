#ifndef AUDIO_KERNELS_RUST_H
#define AUDIO_KERNELS_RUST_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct AKResultCode {
    int32_t code;
} AKResultCode;

typedef struct AKRmsPeakResult {
    float rms_linear;
    float peak_linear;
} AKRmsPeakResult;

uint32_t ak_version(void);

AKResultCode ak_compute_rms_peak_f32(
    const float *samples,
    size_t sample_count,
    AKRmsPeakResult *out_result
);

#ifdef __cplusplus
}
#endif

#endif
