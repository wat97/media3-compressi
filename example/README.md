# vidsqueeze_example

Example app for `vidsqueeze` Flutter plugin.

Current scope:

- listens to native compression state stream
- keeps plugin wiring buildable on Android and iOS
- acts as Flutter-side harness while native cores mature

Run:

```bash
flutter run
```

Current UI is intentionally minimal. For native-core validation:

- Android: use `android/sample-app`
- iOS: use `ios/SampleApp`
