# AudioKernelsRust (pilot skeleton)

Pilot crate for migrating audio math kernels to Rust using a manual C-ABI.

Scope in this initial skeleton:
- no Swift build integration yet,
- no runtime linking yet,
- stable C header and one pure-math exported function for iterative integration.

## Build

```bash
cargo build
cargo test
```

Artifacts are generated under `target/`.

## ABI

Header file:
- `include/audio_kernels_rust.h`

Current exports:
- `ak_version`
- `ak_compute_rms_peak_f32`

Rules followed in this pilot:
- plain pointers and lengths (`const float*`, `size_t`),
- POD output structs,
- explicit result codes,
- caller-owned buffers.

## Result Codes

- `0` => success
- `1` => null pointer
- `2` => invalid argument
