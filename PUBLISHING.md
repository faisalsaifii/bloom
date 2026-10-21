# Publishing Bloom

Run `pwsh tools/build.ps1` (needs Godot 4.5.1 + export templates). Output goes to `build/`.

| Platform | Output | Status |
|---|---|---|
| Windows | `build/windows/Bloom.exe` (single file, Bloom icon + version info patched with rcedit) | ready (unsigned) |
| Linux | `build/linux/Bloom.x86_64` | ready |
| macOS | `build/macos/Bloom.zip` (universal) | ready, **unsigned/not notarized** |
| Web | `build/web/` (PWA, single-thread, runs on itch.io / any static host) | ready |
| Android | `build/android/Bloom.apk` (arm64 + armv7, release-signed) | ready for sideload / APK stores |
| iOS | `build/ios/Bloom.xcodeproj` | needs a Mac + Apple developer account |

## Things only you can do
- **Android signing key**: `signing/bloom-release.keystore` (alias `bloom`) was generated for this project; its password lives in `.godot/export_credentials.cfg`. Both are git-ignored. **Back them up** - losing the key means you can never update the app on Google Play.
- **Google Play needs an AAB**, not an APK: install the Android build template in the Godot editor (Project > Install Android Build Template), set the Android preset to *Use Gradle Build* + export format *AAB*.
- **iOS**: open `build/ios/Bloom.xcodeproj` on a Mac, set your team, set `application/app_store_team_id` in the iOS export preset, then archive. Bundle id is `com.faisalsaifi.bloom` - change it (all presets) to your own before publishing.
- **macOS**: sign + notarize with an Apple Developer ID (enable `codesign` / `notarization` in the macOS preset) or users must right-click > Open.
- **Windows**: code-sign `Bloom.exe` to avoid SmartScreen warnings.
- Replace `config/windows_native_icon`/store listing text and add a privacy policy URL (the game collects no data and has no network access or ads).

## Branding
The Godot logo is never shown: the boot splash is Bloom's own (`assets/branding/splash.png`), the web page uses `web/shell.html`, and every platform icon is generated from the Bloom mark.
