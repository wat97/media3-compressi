# Changelog

## 0.1.0-dev.2

- Clarified supported SDK and platform surface for pub.dev.
- Expanded README with production-style installation, usage, progress,
  cancellation, preset, and platform setup guidance.
- Added `CompressionResolutionCap` enum for resolution-cap selection.
- Marked generated Dart API documentation output as ignored.

## 0.1.0-dev.1

- Initial `vidsqueeze` Flutter plugin scaffolding
- Added Dart compression API contract
- Added Flutter method-channel and event-channel surface
- Added Android plugin bridge over existing `android/compressor-core`
- Added iOS plugin bridge over native `AVAssetReader` / `AVAssetWriter` engine
- Added contract alignment for Flutter, Android, and iOS bridge payloads
- Added Dart-side request validation
- Added Flutter example scaffold with end-to-end compression flow
- Added native iOS sample harness for direct engine validation
- Kept `android/sample-app` as internal Android validation harness
