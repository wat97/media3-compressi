# Vidsqueeze Architecture

## Goals

- Prepare repo for Flutter plugin release shape.
- Keep Android native core as current stable implementation detail.
- Prepare iOS-native parity scaffolding for future core implementation.
- Bias toward zero-corruption output and stable fallback before aggressive size reduction.

## Modules

- `lib`
  - Public Dart compression-only API surface
- `android`
  - Flutter plugin Android bridge
- `compressor-core`
  - Native Android compression engine
  - Policy engine, capability probing, Media3 orchestration, validation, and error mapping
- `ios`
  - Native iOS parity scaffolding
  - Request, preset, policy, and fallback model preparation for `iOS 14+`
- `sample-app`
  - Internal Android verification harness
- `example`
  - Flutter example scaffold

## V1 Defaults

- Preset: `BALANCED`
- Inputs: local `file://`, `content://`, and app cache/temp sources
- Execution: foreground only
- Codec policy:
  - API 34+: prefer HEVC when hardware encode available
  - API 29-33: prefer AVC hardware encode
  - API 23-28: AVC with safer caps
- Resolution policy:
  - Never upscale
  - Preserve aspect ratio
  - Cap >1080p down to 1080p

## Failure Strategy

- Let Media3 encoder fallback stay enabled for safe device-driven fallback.
- Retry once in app policy when preferred codec path fails.
- Validate output before promoting temp file to final destination.
- Return domain-level error codes to keep Flutter bridge thin.
