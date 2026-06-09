# Vidsqueeze Native Sample App

Standalone SwiftUI harness project for exercising the native iOS compression core without Flutter.

## Notes

- Open `ios/SampleApp/vidsqueeze-sample.xcodeproj` in Xcode.
- The app target directly compiles native engine files from `ios/Classes/`.
- Default bundle id is `dev.wat.vidsqueeze.sample`. Change it if it conflicts with your local signing setup.
- Set your own Apple Development team in Xcode before installing to a physical device.
- `VidsqueezePlugin.swift` is intentionally excluded so this harness measures the native core, not the Flutter bridge.
- Source import paths currently support Files and Photos picker flows.
- Validation build command:
  `xcodebuild build -project ios/SampleApp/vidsqueeze-sample.xcodeproj -scheme vidsqueeze-sample -destination 'generic/platform=iOS' -derivedDataPath .xcodebuild/ios-sample CODE_SIGNING_ALLOWED=NO`
