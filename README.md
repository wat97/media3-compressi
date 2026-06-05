# media3-compressi

Native Android video compression with Media3 Transformer, hardware-aware fallback, and Flutter-ready integration.

## Overview

`media3-compressi` is Android-native workspace for on-device video compression built with Kotlin and Jetpack Media3 Transformer. Project is designed to replace older third-party compression stacks with more stable hardware-aware pipeline that can later be exposed to Flutter through thin platform-channel adapter.

Current workspace includes:

- `compressor-core`
  - Kotlin library for compression policy, fallback planning, output validation, and Media3 orchestration.
- `sample-app`
  - Android app for manual testing with source picker, resolution selector, progress display, and source-vs-output comparison.
- `docs`
  - Architecture notes and benchmark template.

## Current V1 Scope

- Min SDK `23`
- Primary optimization for Android `14+`
- Local input sources only: `file://`, `content://`, app cache/temp
- Foreground execution only
- Default quality mode: `BALANCED`
- Codec strategy:
  - API `34+`: prefer `HEVC`
  - API `29-33`: default `AVC`
  - API `23-28`: conservative `AVC`

## Run

Build logic tests:

```bash
./gradlew :compressor-core:testDebugUnitTest
```

Build sample app:

```bash
./gradlew :sample-app:assembleDebug
```

Install sample app to connected device:

```bash
./gradlew :sample-app:installDebug
```

## Sample App Flow

1. Pick video source from device storage.
2. Choose target resolution: `Original`, `1080p`, `720p`, or `480p`.
3. Start compression.
4. Review source vs output:
   - resolution
   - output codec
   - bitrate
   - input size in MB
   - output size in MB
   - saved size in MB

## Testing

- Logic tests cover:
  - codec selection
  - bitrate planning
  - resolution cap decisions
  - fallback planning
  - error classification
- Manual device testing is done through `sample-app` because real export depends on Android runtime and hardware codec behavior.

## Notes

- `gradle-wrapper.jar` is included so project can build immediately.
- `local.properties` is intentionally ignored; each machine should point to its own Android SDK path.
- Flutter bridge is not included yet. Core API is shaped so Flutter integration can stay thin later.

## Docs

- [Architecture](docs/architecture.md)
- [Benchmark Template](docs/benchmark-template.md)

