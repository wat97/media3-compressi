# vidsqueeze

Flutter video compression plugin powered by native Android and iOS encoders.

`vidsqueeze` keeps the Flutter API small and platform-neutral while delegating
heavy media work to native engines:

- Android: Jetpack Media3 Transformer with hardware encoder fallback.
- iOS: AVFoundation (`AVAssetReader` + `AVAssetWriter`) with compatibility
  fallback.
- Flutter: method-channel contract, progress stream, request/result models.

Current v1 scope is compression only. No thumbnail API, remote URL input,
direct `PHAsset` input, background service orchestration, or caller-selected
container yet.

## Install

```bash
flutter pub add vidsqueeze
```

Or add it manually:

```yaml
dependencies:
  vidsqueeze: ^0.1.0-dev.3
```

Then install dependencies:

```bash
flutter pub get
```

### Platform Setup

#### Android

`vidsqueeze` uses native Android encoders through Media3. Minimum supported
Android API is 23.

If your app reads videos from shared storage or a picker, handle permissions or
use a file picker package in the app layer. The plugin expects a readable local
input path and a writable output directory.

#### iOS

`vidsqueeze` uses AVFoundation and supports iOS 14+. If your app lets users
pick videos from Photos, add the Photos permission text required by your picker
flow in `ios/Runner/Info.plist`.

For example:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Select videos to compress.</string>
```

---

## Usage

### 1. Import Package

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vidsqueeze/vidsqueeze.dart';
```

### 2. Listen To Progress

Subscribe before starting compression so the UI receives early states such as
`preparing`.

```dart
late final StreamSubscription<CompressionState> subscription;

subscription = Vidsqueeze.instance.states().listen((state) {
  switch (state.phase) {
    case CompressionPhase.preparing:
      debugPrint('Preparing ${state.taskId}');
    case CompressionPhase.transcoding:
      debugPrint('Progress ${state.progressPercent ?? 0}%');
    case CompressionPhase.finalizing:
      debugPrint('Finalizing output');
    case CompressionPhase.completed:
      debugPrint('Completed ${state.taskId}');
    case CompressionPhase.failed:
      debugPrint('Failed ${state.code}: ${state.message}');
    case CompressionPhase.cancelled:
      debugPrint('Cancelled ${state.taskId}');
  }
});
```

Dispose the subscription with the screen or controller that owns the
compression UI.

```dart
await subscription.cancel();
```

### 3. Compress A Local Video

Use app-owned local paths. Picker packages commonly return either a local file
path or a temporary copied file. Output directory must already exist and be
writable by the app.

```dart
final taskId = DateTime.now().microsecondsSinceEpoch.toString();

final request = CompressionRequest(
  taskId: taskId,
  inputPath: inputFile.path,
  outputDirectoryPath: outputDirectory.path,
  outputFileName: 'vidsqueeze_$taskId.mp4',
  preset: CompressionPreset.balanced,
  maxResolutionCap: CompressionResolutionCap.p1080,
  allowHevc: true,
  keepAudio: true,
  keepOriginalIfLarger: true,
  forceCodec: ForceCodec.auto,
  maxBitrate: null,
  progressIntervalMs: 250,
);

final result = await Vidsqueeze.instance.compress(request);

print(result.outputPath);
print(result.outputSizeBytes);
print(result.usedOriginalSource);
```

### 4. Choose A Preset

| Preset | Best for |
|---|---|
| `CompressionPreset.quality` | Higher visual quality and less aggressive bitrate reduction |
| `CompressionPreset.balanced` | Default user-facing compression |
| `CompressionPreset.smallSize` | Smaller files when quality tradeoff is acceptable |

`maxResolutionCap` is a height cap, not a forced resize. The engine never
upscales. For example, `CompressionResolutionCap.p1080` keeps 720p input at
720p and caps 4K input to 1080p. Use `CompressionResolutionCap.original` to keep
the source resolution.

### 5. Codec Control

Use `ForceCodec.auto` for most apps. It lets the native engine choose a safe
path and fallback when needed.

```dart
final request = CompressionRequest(
  inputPath: inputFile.path,
  outputDirectoryPath: outputDirectory.path,
  forceCodec: ForceCodec.auto,
  allowHevc: true,
);
```

Use forced codecs only when your product has a strict compatibility target.

```dart
final avcOnly = CompressionRequest(
  inputPath: inputFile.path,
  outputDirectoryPath: outputDirectory.path,
  forceCodec: ForceCodec.avc,
  allowHevc: false,
);
```

### 6. Cancel Active Compression

Pass the same `taskId` used in the request.

```dart
await Vidsqueeze.instance.cancel(taskId);
```

Cancellation is best-effort. Native work is stopped and a `cancelled` state is
emitted when the platform pipeline confirms cancellation.

### 7. Read Result Metadata

```dart
final savedBytes = result.sourceSizeBytes - result.outputSizeBytes;
final savedPercent = result.sourceSizeBytes == 0
    ? 0
    : (savedBytes / result.sourceSizeBytes * 100).round();

debugPrint('Output: ${result.outputPath}');
debugPrint('Codec: ${result.codec.value}');
debugPrint('Target height: ${result.targetHeight ?? 'original'}');
debugPrint('Target bitrate: ${result.targetBitrate}');
debugPrint('Attempts: ${result.attempts}');
debugPrint('Saved: $savedPercent%');
```

When `keepOriginalIfLarger` is `true`, `usedOriginalSource` can be `true`. This
means compression completed but the compressed output was larger than the
source, so the engine returned the original path for better user outcome.

### 8. Handle Errors

`compress` can throw `PlatformException` for native failures and channel
contract failures.

```dart
try {
  final result = await Vidsqueeze.instance.compress(request);
  // Use result.outputPath.
} on PlatformException catch (error) {
  debugPrint('vidsqueeze failed: ${error.code} ${error.message}');
}
```

For user-facing UI, prefer listening to `states()` as well. Failed states carry
native error `code` and `message` when available.

---

## Public API

| Type | Purpose |
|---|---|
| `Vidsqueeze` | Plugin entry point and state stream owner |
| `CompressionRequest` | Platform-neutral compression request |
| `CompressionResult` | Output path, size, codec, duration, attempts |
| `CompressionState` | Phase and progress event |
| `CompressionPreset` | `balanced`, `quality`, `smallSize` |
| `CompressionResolutionCap` | `original`, `p2160`, `p1440`, `p1080`, `p720`, `p540`, `p480` |
| `ForceCodec` | `auto`, `avc`, `hevc` |

### Request Fields

| Field | Type | Default | Notes |
|---|---|---|---|
| `taskId` | `String?` | generated | Optional caller-visible task id |
| `inputPath` | `String` | required | Local file URI/path depending on platform bridge |
| `outputDirectoryPath` | `String` | required | Existing/writable output directory |
| `outputFileName` | `String?` | generated | Must be non-empty when provided |
| `preset` | `CompressionPreset` | `balanced` | Quality/size policy |
| `maxResolutionCap` | `CompressionResolutionCap` | `p1080` | Target max height enum, never upscales |
| `forceCodec` | `ForceCodec` | `auto` | Force AVC/HEVC or use platform policy |
| `maxBitrate` | `int?` | `null` | Bits per second cap |
| `allowHevc` | `bool` | `true` | Allows HEVC when safe and supported |
| `keepAudio` | `bool` | `true` | Keep or remove source audio |
| `keepOriginalIfLarger` | `bool` | `true` | Return original if compressed file is larger |
| `progressIntervalMs` | `int` | `250` | Native progress throttle interval |

Validation is intentionally strict: required strings must be non-empty,
`maxBitrate` must be greater than zero when set, and `progressIntervalMs` must
be greater than zero.

---

## Native Android

Android implementation lives in two layers:

- Flutter plugin wrapper: `android/`
- Native engine module: `android/compressor-core/`
- Native validation app: repository-only `android/sample-app/`
- Standalone Gradle runner: repository-only `android/workspace/`

### Engine

- Minimum API: 23
- Core dependency: `androidx.media3:media3-transformer`
- Encoder path: device hardware codecs through Media3
- Output container: MP4
- Default policy: balanced preset, 1080p cap, audio kept, HEVC allowed

### Codec Policy

| Device/API | Preferred path |
|---|---|
| Android 14+ | HEVC when hardware encode is safe |
| Android 10-13 | AVC for broad stability |
| Android 6-9 | AVC baseline-safe compatibility path |

Android fallback behavior prioritizes valid output over aggressive codec use.
If preferred HEVC path is unavailable or fails, the engine falls back to AVC
where policy allows it.

### Native Android Harness

```bash
./android/workspace/gradlew -p android/workspace :sample-app:installDebug
```

The harness is intentionally separate from Flutter `example/` and is used for
low-level Media3 validation on Android devices.

---

## Native iOS

iOS implementation lives in:

- Flutter plugin wrapper: `ios/`
- Native Swift core: `ios/Classes/`
- Native sample harness: repository-only `ios/SampleApp/`

### Engine

- Minimum iOS: 14
- Core framework: AVFoundation
- Pipeline: `AVAssetReader` + `AVAssetWriter`
- Output container: MP4
- Default policy: balanced preset, 1080p cap, audio kept, HEVC allowed

### Codec Policy

The iOS engine prefers HEVC when safe, supported, and compatible with source
properties. It falls back to AVC once when policy allows. HDR, 10-bit, and
Dolby Vision sources are routed through the compatibility path for v1 instead
of attempting HDR preservation.

### Native iOS Harness

```bash
xcodebuild build \
  -project ios/SampleApp/vidsqueeze-sample.xcodeproj \
  -scheme vidsqueeze-sample \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .xcodebuild/ios-sample \
  CODE_SIGNING_ALLOWED=NO
```

The harness is used for native iOS performance and behavior checks before
Flutter bridge validation.

---

## Repository Layout

```text
.
|-- lib/                         # Public Dart API and method-channel contract
|-- android/                     # Flutter Android plugin wrapper
|   |-- src/                     # Android bridge code
|   |-- compressor-core/         # Reusable Android Media3 engine
|   |-- sample-app/              # Repository-only native Android harness
|   `-- workspace/               # Repository-only Gradle runner
|-- ios/                         # Flutter iOS plugin wrapper + native core
|   |-- Classes/                 # Native Swift compression core
|   |-- Tests/                   # Repository-only iOS native unit tests
|   `-- SampleApp/               # Repository-only native iOS harness
|-- example/                     # Public Flutter plugin example app
|-- benchmarks/
|   `-- video_compress_compare/  # Repository-only benchmark vs video_compress
|-- test/                        # Dart unit/contract tests
|-- pubspec.yaml                 # Flutter package metadata
|-- vidsqueeze.podspec           # Flutter plugin podspec
`-- README.md
```

Generated folders such as `.dart_tool/`, `build/`, `.gradle/`, `.kotlin/`,
`.xcodebuild/`, `ios/Pods/`, and app-local build outputs are ignored. Internal
validation harnesses and benchmarks are kept in the GitHub repository but
excluded from the pub.dev package archive.

---

## Example

```bash
cd example
flutter run
```

The public Flutter example validates the package API: pick video, configure a
request, compress, stream progress, and inspect the result.

## Repository-Only Harnesses

The repository also contains validation harnesses that are intentionally
excluded from the pub.dev archive:

- [Native Android harness](https://github.com/wat97/media3-compressi/tree/main/android/sample-app)
- [Native iOS harness](https://github.com/wat97/media3-compressi/tree/main/ios/SampleApp)
- [Benchmark vs video_compress](https://github.com/wat97/media3-compressi/tree/main/benchmarks/video_compress_compare)

The benchmark harness compares `vidsqueeze` against `video_compress` using the
same selected input. It is not the public example app because it includes a
competitor dependency and benchmark-specific UI.

Default benchmark order:

1. Run `video_compress`.
2. Wait 10 seconds.
3. Run `vidsqueeze`.
4. Show comparison and per-engine raw result cards.

---

## Build And Test

### Flutter

```bash
flutter analyze
flutter test
```

### Flutter Example

```bash
cd example
flutter analyze
flutter test
flutter build apk --debug
```

### Android Core

```bash
./android/workspace/gradlew -p android/workspace :compressor-core:testDebugUnitTest
./android/workspace/gradlew -p android/workspace :sample-app:assembleDebug
```

### iOS Core

```bash
cd ios
swift test --disable-sandbox
```

### Benchmark App

```bash
cd benchmarks/video_compress_compare
flutter analyze
flutter test
flutter build apk --debug
```

---

## Current Limits

- Compression only; no thumbnail/media-info utility API.
- Local file input only.
- MP4 output only.
- Single active compression task per plugin instance.
- Direct Photos/`PHAsset` input is not part of v1.
- Remote URL input is not part of v1.
- Background service/job scheduling is caller-owned.

---

## Status

Android and iOS native cores are present. Flutter bridge and examples are being
hardened toward a pub.dev-ready v1 release.
