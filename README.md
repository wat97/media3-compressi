# vidsqueeze

Flutter video compression plugin scaffold with Android Media3 core and iOS-native parity preparation.

## Overview

`vidsqueeze` is cross-platform plugin workspace being prepared for `pub.dev`. Current implementation still centers on Android-native `compressor-core`, while Flutter package structure, Android plugin bridge, and iOS-native parity scaffolding are now in place.

Current workspace includes:

- `lib`
  - Public Dart API contract for compression-only plugin surface
- `android`
  - Flutter plugin Android bridge skeleton over native Android core
- `ios`
  - Native iOS parity scaffolding for `iOS 14+`
- `compressor-core`
  - Native Android engine retained as implementation detail
- `sample-app`
  - Internal Android validation harness for native engine behavior
- `example`
  - Minimal Flutter example app scaffold
- `docs`
  - Architecture notes and benchmark template

## Core Focus

Primary implementation maturity today is still `compressor-core`.

Plugin direction is intended to be:

- reusable across Flutter apps
- configurable without exposing fragile codec internals to Dart callers
- safe by default
- backed by native Android and iOS engines

Current non-goals:

- background service/job orchestration
- end-user UI library
- highly manual codec tuning knobs

## Flutter API Direction

Public Dart API currently prepares:

- `Vidsqueeze.instance.compress(request)`
- `Vidsqueeze.instance.states()`
- `CompressionRequest`
- `CompressionPreset`
- `ForceCodec`
- `CompressionState`
- `CompressionResult`

Request knobs exposed to Flutter:

- `preset`
- `maxResolutionCap`
- `allowHevc`
- `keepAudio`
- `keepOriginalIfLarger`
- `forceCodec`
- `maxBitrate`
- `progressIntervalMs`

Default behavior stays conservative so host apps can start simple and override only when needed.

Public presets:

- `CompressionPreset.QUALITY`
- `CompressionPreset.BALANCED`
- `CompressionPreset.SMALL_SIZE`

## Dart Usage

```kotlin
final request = CompressionRequest(
  inputPath: 'content://media/external/video/media/1',
  outputDirectoryPath: '/tmp/output',
  preset: CompressionPreset.quality,
  maxResolutionCap: 720,
  forceCodec: ForceCodec.auto,
  maxBitrate: 3000000,
);

final result = await Vidsqueeze.instance.compress(request);
```

State stream:

```dart
Vidsqueeze.instance.states().listen((state) {
  print('${state.phase.value} ${state.progressPercent}');
});
```

## Native API Surface

Android native source-of-truth today:

- `VideoCompressor`
- `CompressionRequest`
- `CompressionPreset`
- `ForceCodec`
- `CompressionListener`
- `CompressionState`
- `CompressionSuccess`
- `CompressionFailure`

## Current V1 Scope

- Flutter package structure prepared
- Android plugin bridge skeleton added
- iOS parity models/policy scaffolding added for `iOS 14+`
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

Build Android native core logic tests:

```bash
./gradlew :compressor-core:testDebugUnitTest
```

Build Android native core artifacts:

```bash
./gradlew :compressor-core:assemble
```

Build internal Android harness:

```bash
./gradlew :sample-app:assembleDebug
```

Install internal Android harness:

```bash
./gradlew :sample-app:installDebug
```

## Internal Android Harness

1. Pick video source from device storage.
2. Choose preset and variable overrides.
3. Start compression.
4. Review source vs output:
   - resolution
   - output codec
   - bitrate
   - input size in MB
   - output size in MB
   - saved size in MB

`sample-app` exists to verify `compressor-core` on real devices. It is not primary product surface of this repo.

## Testing

- Verified now:
  - request builder / DSL creation
  - codec selection
  - bitrate planning
  - resolution cap decisions
  - bitrate cap
  - audio removal decisions
  - fallback planning
  - error classification
- Flutter package structure and iOS scaffolding are prepared, but not fully runtime-verified in this environment because Flutter SDK permissions are currently blocked.
- Manual device testing is done through `sample-app` because real export depends on Android runtime and hardware codec behavior.

## Notes

- `gradle-wrapper.jar` is included so project can build immediately.
- `local.properties` is intentionally ignored; each machine should point to its own Android SDK path.
- `compressor-core` remains current Android implementation detail and reference contract.
- Android Flutter bridge is intentionally thin in this phase.
- iOS native core files currently focus on parity models and policy scaffolding before full export wiring.

## Docs

- [Architecture](docs/architecture.md)
- [Benchmark Template](docs/benchmark-template.md)
