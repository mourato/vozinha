#![deny(unsafe_op_in_unsafe_fn)]

#[repr(C)]
pub struct AKResultCode {
    pub code: i32,
}

#[repr(C)]
pub struct AKRmsPeakResult {
    pub rms_linear: f32,
    pub peak_linear: f32,
}

const AK_OK: i32 = 0;
const AK_ERR_NULL_POINTER: i32 = 1;
const AK_ERR_INVALID_ARGUMENT: i32 = 2;

#[no_mangle]
pub extern "C" fn ak_version() -> u32 {
    1
}

#[no_mangle]
pub unsafe extern "C" fn ak_compute_rms_peak_f32(
    samples: *const f32,
    sample_count: usize,
    out_result: *mut AKRmsPeakResult,
) -> AKResultCode {
    if samples.is_null() || out_result.is_null() {
        return AKResultCode {
            code: AK_ERR_NULL_POINTER,
        };
    }

    if sample_count == 0 {
        return AKResultCode {
            code: AK_ERR_INVALID_ARGUMENT,
        };
    }

    let slice = {
        unsafe { std::slice::from_raw_parts(samples, sample_count) }
    };

    let mut sum_squares: f32 = 0.0;
    let mut peak: f32 = 0.0;

    for sample in slice {
        let value = sample.abs();
        sum_squares += value * value;
        if value > peak {
            peak = value;
        }
    }

    let rms = (sum_squares / sample_count as f32).sqrt();

    unsafe {
        *out_result = AKRmsPeakResult {
            rms_linear: rms,
            peak_linear: peak,
        };
    }

    AKResultCode { code: AK_OK }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn computes_rms_peak_for_simple_vector() {
        let samples = [0.0_f32, 1.0, 0.0, -1.0];
        let mut out = AKRmsPeakResult {
            rms_linear: 0.0,
            peak_linear: 0.0,
        };

        let result = unsafe { ak_compute_rms_peak_f32(samples.as_ptr(), samples.len(), &mut out) };

        assert_eq!(result.code, AK_OK);
        assert!((out.rms_linear - 0.70710677).abs() < 1e-6);
        assert!((out.peak_linear - 1.0).abs() < 1e-6);
    }
}
