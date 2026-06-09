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

---

## Install

```bash
flutter pub add vidsqueeze
```

Package is still under active preparation for public release. Until published,
use a path or git dependency from consuming apps.

---

## Flutter Usage

### Compress Video

```dart
final request = CompressionRequest(
  inputPath: 'file:///storage/emulated/0/Movies/input.mp4',
  outputDirectoryPath: '/storage/emulated/0/Movies/Compressed',
  outputFileName: 'compressed.mp4',
  preset: CompressionPreset.balanced,
  maxResolutionCap: 1080,
  forceCodec: ForceCodec.auto,
  maxBitrate: 3_000_000,
  allowHevc: true,
  keepAudio: true,
  keepOriginalIfLarger: true,
  progressIntervalMs: 250,
);

final result = await Vidsqueeze.instance.compress(request);

print(result.outputPath);
print(result.outputSizeBytes);
```

### Listen To Progress

```dart
final subscription = Vidsqueeze.instance.states().listen((state) {
  print('${state.phase.value}: ${state.progressPercent ?? '-'}');
});
```

### Cancel Active Task

```dart
await Vidsqueeze.instance.cancel();
```

---

## Public API

| Type | Purpose |
|---|---|
| `Vidsqueeze` | Plugin entry point and state stream owner |
| `CompressionRequest` | Platform-neutral compression request |
| `CompressionResult` | Output path, size, codec, duration, attempts |
| `CompressionState` | Phase and progress event |
| `CompressionPreset` | `balanced`, `quality`, `smallSize` |
| `ForceCodec` | `auto`, `avc`, `hevc` |

### Request Fields

| Field | Type | Default | Notes |
|---|---|---|---|
| `taskId` | `String?` | generated | Optional caller-visible task id |
| `inputPath` | `String` | required | Local file URI/path depending on platform bridge |
| `outputDirectoryPath` | `String` | required | Existing/writable output directory |
| `outputFileName` | `String?` | generated | Must be non-empty when provided |
| `preset` | `CompressionPreset` | `balanced` | Quality/size policy |
| `maxResolutionCap` | `int?` | `null` | Target max height, never upscales |
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
- Native validation app: `android/sample-app/`
- Standalone Gradle runner: `android/workspace/`

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
- Native sample harness: `ios/SampleApp/`

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
|   |-- sample-app/              # Native Android validation harness
|   `-- workspace/               # Standalone Gradle runner for native modules
|-- ios/                         # Flutter iOS plugin wrapper + native core
|   |-- Classes/                 # Native Swift compression core
|   |-- Tests/                   # iOS native unit tests
|   `-- SampleApp/               # Native iOS validation harness
|-- example/                     # Public Flutter plugin example app
|-- benchmarks/
|   `-- video_compress_compare/  # Internal benchmark vs video_compress
|-- test/                        # Dart unit/contract tests
|-- pubspec.yaml                 # Flutter package metadata
|-- vidsqueeze.podspec           # Flutter plugin podspec
`-- README.md
```

Generated folders such as `.dart_tool/`, `build/`, `.gradle/`, `.kotlin/`,
`.xcodebuild/`, `ios/Pods/`, and app-local build outputs are ignored.

---

## Examples And Benchmarks

### Flutter Example

```bash
cd example
flutter run
```

The Flutter example validates the public API: pick video, configure request,
compress, stream progress, and inspect result.

### Benchmark Harness

```bash
cd benchmarks/video_compress_compare
flutter run -d <device-id>
```

The benchmark harness compares `vidsqueeze` against `video_compress` using the
same selected input. It is not the public example app. It keeps competitor
dependencies and benchmark UI outside `example/`.

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
