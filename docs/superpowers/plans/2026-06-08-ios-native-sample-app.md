# iOS Native Sample App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build standalone native iOS sample app under `ios/SampleApp/` for real-device compression benchmarking using existing iOS native core directly.

**Architecture:** Create separate SwiftUI-based Xcode app under `ios/SampleApp/` and compile `ios/Classes` directly into it. Add local import adapters for Files and Photos, a view model that bridges callback-style compression events into observable UI state, and a benchmark-focused screen with control panel, progress display, and before/after metrics.

**Tech Stack:** SwiftUI, AVFoundation, PhotosUI, UniformTypeIdentifiers, existing native core in `ios/Classes`, Xcode project files, iPhone physical-device validation.

---

## File Structure

- Create: `ios/SampleApp/README.md`
  - documents purpose and run notes for native harness
- Create: `ios/SampleApp/vidsqueeze-sample.xcodeproj/project.pbxproj`
  - standalone Xcode app project
- Create: `ios/SampleApp/vidsqueeze-sample.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
  - workspace metadata
- Create: `ios/SampleApp/vidsqueeze-sample.xcodeproj/xcshareddata/xcschemes/vidsqueeze-sample.xcscheme`
  - shared run scheme
- Create: `ios/SampleApp/Sources/VidsqueezeSampleApp.swift`
  - SwiftUI app entry
- Create: `ios/SampleApp/Sources/CompressionHarnessView.swift`
  - primary benchmark UI
- Create: `ios/SampleApp/Sources/CompressionHarnessViewModel.swift`
  - observable state, request building, listener bridging, elapsed timing
- Create: `ios/SampleApp/Sources/CompressionBenchmarkModels.swift`
  - source/result summary models for UI
- Create: `ios/SampleApp/Sources/CompressionOptionModels.swift`
  - UI-facing preset/resolution/codec option wrappers
- Create: `ios/SampleApp/Sources/CompressionSessionAdapter.swift`
  - adapter from native listener callbacks into view model updates
- Create: `ios/SampleApp/Sources/FileImportService.swift`
  - Files picker import normalization to local URL
- Create: `ios/SampleApp/Sources/PhotoImportService.swift`
  - Photos picker import/export normalization to local URL
- Create: `ios/SampleApp/Sources/MediaInspectorFormatter.swift`
  - MB formatting, dimensions, duration text, percent saved
- Create: `ios/SampleApp/Sources/DocumentPicker.swift`
  - SwiftUI wrapper for UIDocumentPickerViewController
- Create: `ios/SampleApp/Sources/PhotoPicker.swift`
  - SwiftUI wrapper for PHPickerViewController
- Create: `ios/SampleApp/Sources/Info.plist`
  - app metadata and Photos usage descriptions
- Create: `ios/SampleApp/Assets.xcassets/...`
  - app icon / accent / base assets
- Create: `ios/SampleApp/Tests/CompressionHarnessViewModelTests.swift`
  - view model / adapter tests when logic is stable enough
- Modify: `ios/Classes/VidsqueezeCompressionModels.swift`
  - expose helpers if harness needs shared inspection/result formatting inputs
- Modify: `README.md`
  - add native iOS sample app section and run command
- Modify: `.gitignore`
  - ignore `ios/SampleApp/build/` or DerivedData-style artifacts if needed

## Task 1: Scaffold Native iOS Sample App Project

**Files:**
- Create: `ios/SampleApp/README.md`
- Create: `ios/SampleApp/vidsqueeze-sample.xcodeproj/project.pbxproj`
- Create: `ios/SampleApp/vidsqueeze-sample.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- Create: `ios/SampleApp/vidsqueeze-sample.xcodeproj/xcshareddata/xcschemes/vidsqueeze-sample.xcscheme`
- Create: `ios/SampleApp/Sources/VidsqueezeSampleApp.swift`
- Create: `ios/SampleApp/Sources/Info.plist`
- Create: `ios/SampleApp/Assets.xcassets/Contents.json`

- [ ] **Step 1: Add project scaffold files**

Create minimal standalone SwiftUI app project under `ios/SampleApp/` with bundle id placeholder for local signing, iOS 14 target, and direct source inclusion for `../../Classes/*.swift`.

- [ ] **Step 2: Run project discovery check**

Run: `find ios/SampleApp -maxdepth 4 -type f | sort`
Expected: project file, scheme, app source, plist, and asset catalog files exist

- [ ] **Step 3: Commit scaffold**

```bash
git add ios/SampleApp
git commit -m "feat(ios): scaffold native sample app"
```

## Task 2: Build Core Harness State Models

**Files:**
- Create: `ios/SampleApp/Sources/CompressionBenchmarkModels.swift`
- Create: `ios/SampleApp/Sources/CompressionOptionModels.swift`
- Create: `ios/SampleApp/Sources/MediaInspectorFormatter.swift`
- Test: `ios/SampleApp/Tests/CompressionHarnessViewModelTests.swift`

- [ ] **Step 1: Write failing tests for benchmark formatting**

Test behaviors:
- MB formatting rounds to familiar decimal output
- saved percent uses source/output sizes correctly
- option wrappers map to native request values correctly

- [ ] **Step 2: Run test command and verify failure**

Run: `xcodebuild test -project ios/SampleApp/vidsqueeze-sample.xcodeproj -scheme vidsqueeze-sample -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: fail because formatter and option model files do not exist yet

- [ ] **Step 3: Implement minimal benchmark and option models**

Add:
- source summary model
- output summary model
- benchmark summary model
- codec/preset/resolution option enums
- formatter helpers for size, duration, dimensions, percent

- [ ] **Step 4: Run tests and verify pass**

Run same command from Step 2.
Expected: formatter and option-model tests pass

- [ ] **Step 5: Commit**

```bash
git add ios/SampleApp/Sources/CompressionBenchmarkModels.swift ios/SampleApp/Sources/CompressionOptionModels.swift ios/SampleApp/Sources/MediaInspectorFormatter.swift ios/SampleApp/Tests/CompressionHarnessViewModelTests.swift
git commit -m "feat(ios): add harness benchmark models"
```

## Task 3: Add Files And Photos Import Adapters

**Files:**
- Create: `ios/SampleApp/Sources/FileImportService.swift`
- Create: `ios/SampleApp/Sources/PhotoImportService.swift`
- Create: `ios/SampleApp/Sources/DocumentPicker.swift`
- Create: `ios/SampleApp/Sources/PhotoPicker.swift`
- Modify: `ios/SampleApp/Sources/Info.plist`
- Test: `ios/SampleApp/Tests/CompressionHarnessViewModelTests.swift`

- [ ] **Step 1: Write failing tests for import normalization contracts**

Test behaviors:
- imported item returns sandbox-local file URL
- unsupported type produces error
- picker cancellation does not crash state flow

- [ ] **Step 2: Run tests and verify failure**

Run: `xcodebuild test -project ios/SampleApp/vidsqueeze-sample.xcodeproj -scheme vidsqueeze-sample -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: fail because import services and picker wrappers do not exist yet

- [ ] **Step 3: Implement minimal import services and picker wrappers**

Add:
- document picker wrapper
- photos picker wrapper
- copy/import helper for security-scoped files
- photo export helper using `loadFileRepresentation`
- required Photos usage descriptions in plist

- [ ] **Step 4: Run tests and verify pass**

Run same command from Step 2.
Expected: import service tests pass

- [ ] **Step 5: Commit**

```bash
git add ios/SampleApp/Sources/FileImportService.swift ios/SampleApp/Sources/PhotoImportService.swift ios/SampleApp/Sources/DocumentPicker.swift ios/SampleApp/Sources/PhotoPicker.swift ios/SampleApp/Sources/Info.plist ios/SampleApp/Tests/CompressionHarnessViewModelTests.swift
git commit -m "feat(ios): add sample app import adapters"
```

## Task 4: Build Compression Session Adapter

**Files:**
- Create: `ios/SampleApp/Sources/CompressionSessionAdapter.swift`
- Test: `ios/SampleApp/Tests/CompressionHarnessViewModelTests.swift`

- [ ] **Step 1: Write failing tests for callback bridging**

Test behaviors:
- preparing/transcoding/finalizing/completed states map into observable harness state
- failure exposes code and message
- cancellation exposes cancelled phase
- elapsed timer starts/stops correctly

- [ ] **Step 2: Run tests and verify failure**

Run: `xcodebuild test -project ios/SampleApp/vidsqueeze-sample.xcodeproj -scheme vidsqueeze-sample -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: fail because adapter does not exist

- [ ] **Step 3: Implement minimal session adapter**

Adapter should:
- own native `VidsqueezeCompressionHandle`
- implement `VidsqueezeCompressionListener`
- forward callbacks onto main actor / main queue
- track session start/end timestamps

- [ ] **Step 4: Run tests and verify pass**

Run same command from Step 2.
Expected: callback adapter tests pass

- [ ] **Step 5: Commit**

```bash
git add ios/SampleApp/Sources/CompressionSessionAdapter.swift ios/SampleApp/Tests/CompressionHarnessViewModelTests.swift
git commit -m "feat(ios): bridge native compression callbacks"
```

## Task 5: Build View Model

**Files:**
- Create: `ios/SampleApp/Sources/CompressionHarnessViewModel.swift`
- Modify: `ios/Classes/VidsqueezeCompressionModels.swift` if harness needs harmless shared access adjustments
- Test: `ios/SampleApp/Tests/CompressionHarnessViewModelTests.swift`

- [ ] **Step 1: Write failing tests for request building and state transitions**

Test behaviors:
- selected UI options map into `VidsqueezeCompressionRequest`
- source inspect populates source summary
- success populates result summary and benchmark summary
- retry resets prior transient state but preserves selected options

- [ ] **Step 2: Run tests and verify failure**

Run: `xcodebuild test -project ios/SampleApp/vidsqueeze-sample.xcodeproj -scheme vidsqueeze-sample -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: fail because view model does not exist

- [ ] **Step 3: Implement minimal view model**

Include:
- picker result handling
- source inspection
- request creation
- compression start/cancel
- log line accumulation
- source/result/benchmark summaries

- [ ] **Step 4: Run tests and verify pass**

Run same command from Step 2.
Expected: view model tests pass

- [ ] **Step 5: Commit**

```bash
git add ios/SampleApp/Sources/CompressionHarnessViewModel.swift ios/Classes/VidsqueezeCompressionModels.swift ios/SampleApp/Tests/CompressionHarnessViewModelTests.swift
git commit -m "feat(ios): add sample app view model"
```

## Task 6: Build SwiftUI Benchmark Screen

**Files:**
- Create: `ios/SampleApp/Sources/CompressionHarnessView.swift`
- Modify: `ios/SampleApp/Sources/VidsqueezeSampleApp.swift`

- [ ] **Step 1: Add SwiftUI benchmark/control screen**

Screen sections:
- source picker buttons for Files and Photos
- compression control panel
- progress/state panel
- benchmark summary panel
- log area
- cancel / compress actions

- [ ] **Step 2: Run app build check**

Run: `xcodebuild build -project ios/SampleApp/vidsqueeze-sample.xcodeproj -scheme vidsqueeze-sample -destination 'generic/platform=iOS'`
Expected: build succeeds

- [ ] **Step 3: Commit**

```bash
git add ios/SampleApp/Sources/CompressionHarnessView.swift ios/SampleApp/Sources/VidsqueezeSampleApp.swift
git commit -m "feat(ios): add benchmark harness UI"
```

## Task 7: Update Docs And Ignore Rules

**Files:**
- Modify: `README.md`
- Modify: `.gitignore`
- Modify: `ios/SampleApp/README.md`

- [ ] **Step 1: Update documentation**

Document:
- native iOS sample app purpose
- how it differs from Flutter example
- how to run on device
- current signing expectations

- [ ] **Step 2: Add ignore rules if build artifacts appear**

Ensure native sample app build products are ignored.

- [ ] **Step 3: Run doc sanity read**

Run: `sed -n '1,260p' README.md`
Expected: README mentions `ios/SampleApp` as native harness

- [ ] **Step 4: Commit**

```bash
git add README.md .gitignore ios/SampleApp/README.md
git commit -m "docs: document ios native sample app"
```

## Task 8: Validate On Real Device

**Files:**
- Modify: `example/ios/Runner.xcodeproj/project.pbxproj` only if earlier temporary signing changes should be reverted or isolated
- Modify: `example/ios/Podfile` only if earlier temporary changes should be reverted or isolated

- [ ] **Step 1: Build native sample app for generic iOS target**

Run: `xcodebuild build -project ios/SampleApp/vidsqueeze-sample.xcodeproj -scheme vidsqueeze-sample -destination 'generic/platform=iOS'`
Expected: build succeeds

- [ ] **Step 2: Attempt launch on physical device**

Run with actual connected device identifier through `xcodebuild` or `ios-deploy` style path chosen during implementation.
Expected: app installs, launches, and reaches main harness screen

- [ ] **Step 3: Manual real-device checklist**

Verify:
- Files picker path works
- Photos picker path works
- progress updates advance
- result metrics populate
- elapsed time displays
- cancel path works

- [ ] **Step 4: Commit final validation-oriented fixes**

```bash
git add ios/SampleApp README.md .gitignore
git commit -m "feat(ios): finalize native sample harness"
```

## Spec Coverage Check

Covered spec requirements:
- standalone native harness under `ios/SampleApp/`
- SwiftUI UI
- Files and Photos input
- direct native core invocation
- full compression control panel
- benchmark/result panel
- progress/state display
- real device validation task

No placeholder gaps remain. Main open risk is signing/device provisioning, which is explicitly isolated into Task 8 because it depends on local machine account state.
