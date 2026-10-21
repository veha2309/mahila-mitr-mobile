# Android releases

The app version is defined in `pubspec.yaml`: `1.1.0+2` means version 1.1.0, Android build 2. Increment the build number for every new release; increment the semantic version for the changes being shipped.

From the mobile app directory on Windows, run:

```powershell
./tool/build_release.ps1
```

The script synchronizes the version shown in Settings, builds a signed release APK, and writes `mahila-mitr.apk`, `release-info.json`, and `SHA256SUMS.txt` into `build/releases/mahila-mitr/<version>+<build>/`.

The first run creates `android/app/mahila-mitr-release.keystore` and `android/key.properties`. Both are ignored by Git. Back up both securely: subsequent updates must use the same signing key. Release builds require this configuration and never fall back to the debug key.

Publish the APK, metadata, and checksum as assets on the matching GitHub release tag (for example, `v1.0.0`). Keep signing files private.

For Drive distribution, keep the binary named `mahila-mitr.apk` inside a versioned release folder (for example, `Mahila Mitr releases/1.1.0+2/`) alongside `release-info.json` and `SHA256SUMS.txt`. Verify the APK's embedded version and signing certificate before uploading. The Android build number, rather than the file name, determines upgrade order.
