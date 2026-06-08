# vidsqueeze

**Flutter video compression plugin** with native Android (Media3) and iOS (AVFoundation) engines.

`flutter pub add vidsqueeze`

---

## Overview

Vidsqueeze compresses MP4 video on Android and iOS through Flutter with zero quality-corruption bias.

**v1 scope** — compression only, local file/URI input, single active task per plugin instance, progress stream + final result.

---

## Flutter API

### Compress

```dart
final request = CompressionRequest(
  inputPath: 'file:///storage/emulated/0/Movies/input.mp4',
  outputDirectoryPath: '/storage/emulated/0/Movies/Compressed',
  preset: CompressionPreset.balanced,
  maxResolutionCap: 1080,
  forceCodec: ForceCodec.auto,
  maxBitrate: 3_000_000,
  keepAudio: true,
  keepOriginalIfLarger: true,
  progressIntervalMs: 250,
);

final result = await Vidsqueeze.instance.compress(request);
```

### Track Progress

```dart
Vidsqueeze.instance.states().listen((state) {
  print('${state.phase.value} ${state.progressPercent}');
});
```

---

## Request Contract

| Field | Type | Default | Required |
|---|---|---|---|
| `taskId` | `String?` | — | no |
| `inputPath` | `String` | — | **yes** (non-empty) |
| `outputDirectoryPath` | `String` | — | **yes** (non-empty) |
| `outputFileName` | `String?` | `null` | no (non-empty if set) |
| `preset` | `CompressionPreset` | `balanced` | no |
| `maxResolutionCap` | `int?` | `null` | no |
| `forceCodec` | `ForceCodec` | `auto` | no |
| `maxBitrate` | `int?` | `null` | no (>0 if set) |
| `allowHevc` | `bool` | `true` | no |
| `keepAudio` | `bool` | `true` | no |
| `keepOriginalIfLarger` | `bool` | `true` | no |
| `progressIntervalMs` | `int` | `250` | no (>0) |

### Public Types

| Type | Role |
|---|---|
| `Vidsqueeze` | Plugin entry point (singleton) |
| `CompressionRequest` | Compression parameters |
| `CompressionResult` | Output path, size, codec, duration |
| `CompressionState` | Phase + progressPercent |
| `CompressionPreset` | `balanced`, `quality`, `size` |
| `ForceCodec` | `auto`, `avc`, `hevc` |

### Validation

- `inputPath` — must be non-empty
- `outputDirectoryPath` — must be non-empty
- `outputFileName` — non-empty if provided
- `maxBitrate` — must be > 0 if provided
- `progressIntervalMs` — must be > 0

---

## Platform Behaviour

### Android (Media3)

| API Range | Default |
|---|---|
| 34+ | HEVC when HW encode available |
| 29–33 | AVC HW encode |
| 23–28 | AVC with safe caps |

Resolution policy: never upscale, preserve aspect ratio, cap >1080p → 1080p.

### iOS (AVFoundation)

- Minimum: iOS 14+
- Engine: `AVAssetReader` + `AVAssetWriter`
  - Prefers HEVC when safe
  - Retries once with AVC on fallback
- Routes HDR / 10-bit / Dolby Vision sources to compatibility path

### Failure Strategy

- Media3 encoder fallback enabled for safe device-driven fallback
- One app-level retry when preferred codec path fails
- Output validated before promoting temp file to final destination
- Domain-level error codes keep Flutter bridge thin

---

## Example App

[`example/`](./example) exercises full Flutter flow:

- pick source video
- choose preset and request overrides
- start compression through Flutter bridge
- observe progress stream
- inspect final result and output path

Native-only validation harnesses (lower-level, no Flutter in loop):

- Android: [`android/sample-app/`](./android/sample-app)
- iOS: [`ios/SampleApp/`](./ios/SampleApp)

---

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
cd ios && swift test --disable-sandbox
```

Standalone iOS native harness:

```bash
xcodebuild build -project ios/SampleApp/vidsqueeze-sample.xcodeproj -scheme vidsqueeze-sample -destination 'generic/platform=iOS' -derivedDataPath .xcodebuild/ios-sample CODE_SIGNING_ALLOWED=NO
```

---

## Current Limits

- ❌ Thumbnail API
- ❌ Background service/job orchestration
- ❌ Direct `PHAsset` bridge input
- ❌ Remote URL input
- ❌ Caller-selected output container

