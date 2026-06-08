# vidsqueeze

Flutter video compression plugin with native Android and iOS cores.

## Status

Current repo includes:

- Flutter public API in `lib/`
- Android Flutter bridge in `android/`
- iOS Flutter bridge plus native iOS engine in `ios/`
- Android native engine in `android/compressor-core/`
- Flutter example app in `example/`
- internal native validation apps in `android/sample-app/` and `ios/SampleApp/`

Current v1 scope:

- compression only
- local file or URI input
- MP4 output
- single active task per plugin instance
- progress stream plus final result

## Flutter API

```dart
final request = CompressionRequest(
  inputPath: 'file:///storage/emulated/0/Movies/input.mp4',
  outputDirectoryPath: '/storage/emulated/0/Movies/Compressed',
  preset: CompressionPreset.balanced,
  maxResolutionCap: 1080,
  allowHevc: true,
  keepAudio: true,
  keepOriginalIfLarger: true,
  forceCodec: ForceCodec.auto,
  maxBitrate: 3_000_000,
  progressIntervalMs: 250,
);

final result = await Vidsqueeze.instance.compress(request);
```

Progress:

```dart
Vidsqueeze.instance.states().listen((state) {
  print('${state.phase.value} ${state.progressPercent}');
});
```

Public types:

- `Vidsqueeze`
- `CompressionRequest`
- `CompressionResult`
- `CompressionState`
- `CompressionPreset`
- `ForceCodec`

## Request Contract

Request fields:

- `taskId`
- `inputPath`
- `outputDirectoryPath`
- `outputFileName`
- `preset`
- `maxResolutionCap`
- `allowHevc`
- `keepAudio`
- `keepOriginalIfLarger`
- `forceCodec`
- `maxBitrate`
- `progressIntervalMs`

Defaults:

- `preset`: `CompressionPreset.balanced`
- `maxResolutionCap`: `null` in Dart request unless caller sets it
- `allowHevc`: `true`
- `keepAudio`: `true`
- `keepOriginalIfLarger`: `true`
- `forceCodec`: `ForceCodec.auto`
- `progressIntervalMs`: `250`

Dart-side validation:

- `inputPath` must be non-empty
- `outputDirectoryPath` must be non-empty
- `outputFileName`, when provided, must be non-empty
- `maxBitrate`, when provided, must be `> 0`
- `progressIntervalMs` must be `> 0`

## Platform Behavior

### Android

- native engine backed by Media3 pipeline
- API `34+`: prefer HEVC when safe
- API `29-33`: stable AVC default
- API `23-28`: conservative AVC path

### iOS

- minimum `iOS 14+`
- native engine uses `AVAssetReader` + `AVAssetWriter`
- prefers HEVC when safe
- retries once with AVC when fallback is needed
- routes HDR / 10-bit / Dolby Vision style sources to compatibility path

## Example App

`example/` now exercises real Flutter flow:

- pick source video
- choose preset and request overrides
- start compression through Flutter bridge
- observe progress stream
- inspect final result and output path

Native-only harnesses still exist for lower-level validation:

- Android: `android/sample-app/`
- iOS: `ios/SampleApp/`

## Build And Test

### Flutter

```bash
flutter analyze
flutter test
```

### Android

```bash
./android/workspace/gradlew -p android/workspace :compressor-core:testDebugUnitTest
./android/workspace/gradlew -p android/workspace :sample-app:assembleDebug
```

### iOS

```bash
cd ios
swift test --disable-sandbox
```

Standalone iOS native harness:

```bash
xcodebuild build -project ios/SampleApp/vidsqueeze-sample.xcodeproj -scheme vidsqueeze-sample -destination 'generic/platform=iOS' -derivedDataPath .xcodebuild/ios-sample CODE_SIGNING_ALLOWED=NO
```

## Current Limits

- no thumbnail API
- no background service/job orchestration yet
- no direct `PHAsset` bridge input yet
- no remote URL input yet
- no caller-selected output container in v1

## Docs

- [Architecture](docs/architecture.md)
- [Benchmark Template](docs/benchmark-template.md)
