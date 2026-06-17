# Changelog

## 0.1.0-dev.5

- Fixed Android builds when `vidsqueeze` is consumed from pub.dev by removing
  the published plugin dependency on the internal Gradle `:compressor-core`
  subproject.
- Android plugin builds now include the core source set directly and declare
  Media3 dependencies in the plugin module.

## 0.1.0-dev.4

- Hardened `outputFileName` validation across Dart, Android, and iOS so callers
  can only pass plain `.mp4` file names, not path segments or traversal values.
- Added native output path containment checks before promoting compressed output.
- Fixed Android plugin cancellation lifecycle so a new compression task cannot
  start until the previous native task reaches a terminal callback.
- Replaced assert-only Dart request validation with runtime `ArgumentError`
  checks that remain active in release builds.
- Added regression tests for unsafe output file names and request validation.

## 0.1.0-dev.3

- Added Dartdoc comments for the public Dart API to improve pub.dev API
  reference coverage.

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
