# dukanest_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Release versioning

Use semantic versioning in `pubspec.yaml` (`version: x.y.z+build`):

- `x.y.z` = app version shown to users
- `build` = internal build number (must increase every release)

Use the helper script to bump version and build together:

- Patch release:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\bump_version.ps1 -Increment patch`
- Minor release:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\bump_version.ps1 -Increment minor`
- Major release:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\bump_version.ps1 -Increment major`

Then build for Play Console:

- App Bundle (`.aab`, recommended): `flutter build appbundle --release`
- APK (`.apk`, if needed): `flutter build apk --release`
