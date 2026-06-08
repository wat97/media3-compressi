# vidsqueeze

Flutter video compression plugin with native Android and iOS cores.

## Overview

`vidsqueeze` is plugin workspace being prepared for `pub.dev`.

Current repo already contains:

- Flutter package surface in `lib/`
- Android Flutter plugin bridge in `android/`
- iOS Flutter plugin bridge and native compression core in `ios/`
- Android native engine in `compressor-core/`
- Android internal validation harness in `sample-app/`
- iOS native validation harness in `ios/SampleApp/`
- Flutter example app in `example/`

Goal:

- simple compression API for Flutter
- native codec execution on Android and iOS
- safe defaults
- progress stream
- minimal caller-side complexity

## Current Status

What is working now:

- Android native core with Media3-based compression flow
- Android sample harness for real device validation
- Flutter-side request/result/state models
- Android Flutter bridge
- iOS native core with source inspection, policy planning, fallback, validation, cancel, and progress callbacks
- iOS unit tests via Swift Package Manager

What is still limited:

- Flutter end-to-end runtime has not been fully validated on both platforms from this environment
- iOS integration tests may skip on Mac host when local encoder support is unavailable
- input scope is still local file/content sources, not cloud or `PHAsset`

## Public Flutter API

Current Dart surface:

- `Vidsqueeze.instance.compress(request)`
- `Vidsqueeze.instance.states()`
- `CompressionRequest`
- `CompressionPreset`
- `ForceCodec`
- `CompressionState`
- `CompressionResult`

Request knobs:

- `preset`
- `maxResolutionCap`
- `allowHevc`
- `keepAudio`
- `keepOriginalIfLarger`
- `forceCodec`
- `maxBitrate`
- `progressIntervalMs`

Default behavior:

- preset: `balanced`
- resolution cap: `1080`
- keep audio: `true`
- allow HEVC: `true`
- keep original when output is larger: `true`

## Dart Example

```dart
final request = CompressionRequest(
  inputPath: 'content://media/external/video/media/1',
  outputDirectoryPath: '/tmp/output',
  preset: CompressionPreset.balanced,
  maxResolutionCap: 720,
  forceCodec: ForceCodec.auto,
  maxBitrate: 3000000,
);

final result = await Vidsqueeze.instance.compress(request);
```

Progress stream:

```dart
Vidsqueeze.instance.states().listen((state) {
  print('${state.phase.value} ${state.progressPercent}');
});
```

## Native Engines

### Android

Android source-of-truth types:

- `VideoCompressor`
- `CompressionRequest`
- `CompressionPreset`
- `ForceCodec`
- `CompressionListener`
- `CompressionState`
- `CompressionSuccess`
- `CompressionFailure`

Current Android strategy:

- API `34+`: prefer `HEVC` when safe
- API `29-33`: stable `AVC` default
- API `23-28`: conservative `AVC`

### iOS

iOS native core now includes:

- source inspection
- codec capability resolution
- policy engine
- fallback planner
- `AVAssetReader` + `AVAssetWriter` export pipeline
- output validation
- callback-based progress/state reporting
- cancellation

Current iOS strategy:

- minimum `iOS 14+`
- prefer `HEVC` when safe
- fallback to `AVC` once when needed
- compatibility path for HDR / 10-bit / Dolby Vision style sources
- MP4 output only in v1

## Workspace Layout

- `lib/` Flutter public API
- `android/` Flutter plugin Android bridge
- `ios/` Flutter plugin iOS bridge and iOS native core
- `compressor-core/` Android native compression engine
- `sample-app/` internal Android test app
- `example/` Flutter example app
- `docs/` architecture and benchmark notes

## Build And Test

### Android

Run Android unit tests:

```bash
./gradlew :compressor-core:testDebugUnitTest
```

Build Android core:

```bash
./gradlew :compressor-core:assemble
```

Build Android validation app:

```bash
./gradlew :sample-app:assembleDebug
```

Install Android validation app:

```bash
./gradlew :sample-app:installDebug
```

### iOS

Run iOS unit tests with SwiftPM:

```bash
cd ios
swift test --disable-sandbox
```

Notes:

- policy and validation tests run normally
- integration tests may skip on Mac host if encoder support is unavailable for fixture generation

Build the standalone native iOS harness:

```bash
xcodebuild build -project ios/SampleApp/vidsqueeze-sample.xcodeproj -scheme vidsqueeze-sample -destination 'generic/platform=iOS' -derivedDataPath .xcodebuild/ios-sample CODE_SIGNING_ALLOWED=NO
```

Native harness purpose:

- benchmark the pure iOS native compression core
- compare source/output size, codec, resolution, elapsed time, and savings
- validate Files/Photos import paths without Flutter overhead

## Android Validation Harness

`sample-app` is internal app for real-device compression checks.

Flow:

1. Pick source video from device storage.
2. Choose preset and overrides.
3. Start compression.
4. Review result summary.

Current output summary in sample app includes:

- source resolution
- output resolution
- output codec
- target bitrate
- source size in MB
- output size in MB
- saved size in MB

## Verified Coverage

Android verified:

- request builder and validation
- codec selection
- bitrate planning
- resolution cap planning
- bitrate cap behavior
- audio removal decisions
- fallback planning
- error classification

iOS verified:

- codec selection
- HDR/10-bit compatibility fallback behavior
- preset bitrate ordering
- request validation
- fallback retry rules
- output validation
- local MP4 inspect/compress integration path when host encoder is available

## Current Limits

- compression-only scope for v1
- no background job/service orchestration yet
- no thumbnail API yet
- no direct `PHAsset` input yet
- no remote URL input yet
- output container fixed to MP4 in v1

## Docs

- [Architecture](docs/architecture.md)
- [Benchmark Template](docs/benchmark-template.md)
