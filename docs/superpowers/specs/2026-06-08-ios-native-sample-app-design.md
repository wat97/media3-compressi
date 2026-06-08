# iOS Native Sample App Design

## Summary

Add native iOS manual validation harness under `ios/SampleApp/` to measure real native compression performance without Flutter in loop.

Harness will call native compression core in `ios/Classes/` directly. Purpose is parity with Android `sample-app`, but optimized for iOS-native performance investigation first.

## Goals

- run real compression on physical iPhone without Flutter bridge
- measure elapsed compression time and output deltas
- exercise same core request knobs exposed by plugin contract
- support input from Files app and Photos library
- keep app internal-only, not public package surface

## Non-Goals

- polished consumer UI
- background processing
- batch compression
- cloud or remote input
- direct comparison UI against Flutter in same phase

## Proposed Structure

Place harness inside `ios/SampleApp/`.

Planned layout:

- `ios/Classes/`
  - native library code
- `ios/Tests/`
  - unit and integration tests for core
- `ios/SampleApp/`
  - standalone native iOS app project
- `ios/SampleApp/Sources/`
  - SwiftUI screens and app state
- `ios/SampleApp/Shared/`
  - adapters and benchmark models

Reason:

- keeps plugin/library code isolated
- keeps manual test app near iOS implementation
- easier to inspect and evolve than mixing app code into plugin sources

## UI Approach

Use SwiftUI for fast internal harness iteration.

Reason:

- quickest way to build control-heavy internal app
- easier benchmark panel layout
- easier progress/state updates from callback-driven core

## User Flow

1. User chooses video from Files or Photos.
2. App copies selected asset into local temp/sandbox file URL if needed.
3. App inspects source and displays source metrics.
4. User configures compression knobs.
5. User starts compression.
6. App displays live phase and progress.
7. On completion, app shows result metrics and benchmark summary.
8. User can retry with different settings.

## Input Strategy

Support both:

- Files picker
- Photos picker

Implementation notes:

- Files: use `UIDocumentPickerViewController`
- Photos: use `PHPickerViewController`
- normalize both into local file URL before compression

Reason:

- native core currently expects local file URL
- keeps harness aligned with current iOS engine constraint

## Compression Controls

Expose knobs matching native core request contract:

- preset
- max resolution cap
- codec mode
- max bitrate
- keep audio
- keep original if larger
- progress interval

Recommended UI:

- segmented control for preset
- segmented control for codec mode: auto / avc / hevc
- menu or segmented control for resolution cap
- text field or stepper for bitrate
- toggles for audio and keep-original
- small numeric field for progress interval

## Benchmark Panel

Show before/after performance summary:

- source size MB
- output size MB
- saved MB
- saved percent
- source resolution
- output resolution
- source duration
- output duration
- output codec
- target bitrate
- attempts used
- elapsed compression time
- whether original source was kept

Elapsed time measurement:

- start when compression request is submitted
- stop on success or failure callback

## State And Progress

Display native core phases directly:

- preparing
- transcoding with percent
- finalizing
- completed
- failed
- cancelled

Also keep log area for:

- timestamped phase updates
- failure messages
- fallback attempt notes when useful

## Native Wiring

Sample app should call native core directly, not plugin bridge.

Planned path:

- construct `VidsqueezeCompressionRequest`
- call `VidsqueezeVideoCompressor.start(...)`
- listen through callback/listener adapter
- map events into SwiftUI observable state

Reason:

- measures pure native path
- avoids Flutter/channel overhead
- makes debugging iOS core easier

## Error Handling

Need explicit handling for:

- picker cancellation
- unsupported input
- copy/import failure
- codec unavailable
- compression failure
- validation failure
- cancellation

UI behavior:

- preserve last source selection on failure
- show error code and message
- allow immediate retry

## Testing Strategy

Manual validation target:

- run on real iPhone
- compare presets and codec modes
- compare Files vs Photos sourced input
- compare audio-kept vs audio-removed
- compare 720p / 1080p / 4K source behavior

Code-level verification:

- keep existing SwiftPM tests for native core
- add lightweight sample app logic tests only if state adapter grows enough to justify it

## Success Criteria

- app builds as standalone native iOS harness
- can pick video from Files
- can pick video from Photos
- can start compression against existing native core
- can show live progress/state
- can display source/output benchmark summary
- can run on physical iPhone for real native performance checks

## Recommended Implementation Order

1. Create `ios/SampleApp/` project scaffold.
2. Add direct dependency on native core sources.
3. Build source import adapters for Files and Photos.
4. Build SwiftUI benchmark/control screen.
5. Wire compression callbacks into app state.
6. Add result summary panel.
7. Validate on physical iPhone.

## Risks

- iOS signing/project generation may take extra setup time
- Photos-picked assets may require copy/export normalization before use
- some host Mac environments may not fully represent iPhone encoder availability
- manual harness can drift from plugin contract if request knobs are not kept aligned

## Recommendation

Proceed with SwiftUI standalone sample app under `ios/SampleApp/`, wired directly into `ios/Classes/`, with both Files and Photos input and benchmark-focused output.
