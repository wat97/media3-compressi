# Android Video Compression Architecture

## Goals

- Replace third-party compression stack with Kotlin-native Media3 Transformer flow.
- Keep v1 focused on local video sources, foreground execution, and predictable hardware paths.
- Bias toward zero-corruption output and stable fallback before aggressive size reduction.

## Modules

- `compressor-core`
  - Public compression facade
  - Policy engine, capability probing, Media3 orchestration, validation, and error mapping
- `sample-app`
  - Manual verification app for picking a source, choosing target resolution, running compression, and viewing source-vs-output comparison

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
- Return domain-level error codes to keep Flutter bridge thin later.
