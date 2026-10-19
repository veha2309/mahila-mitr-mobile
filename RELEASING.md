# Android releases

The app version is defined in `pubspec.yaml`: `1.0.0+1` means version 1.0.0, Android build 1. Increment the build number for every new release.

From the mobile app directory on Windows, run:

```powershell
./tool/build_release.ps1
```

The script synchronizes the version shown in Settings, builds a signed release APK, and writes `mahila-mitr.apk`, `release-info.json`, and `SHA256SUMS.txt` into `build/releases/mahila-mitr/<version>+<build>/`.

The first run creates `android/app/mahila-mitr-release.keystore` and `android/key.properties`. Both are ignored by Git. Back up both securely: subsequent updates must use the same signing key. Release builds require this configuration and never fall back to the debug key.

Publish the APK, metadata, and checksum as assets on the matching GitHub release tag (for example, `v1.0.0`). Keep signing files private.
