$ErrorActionPreference = 'Stop'
$releaseRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $releaseRoot
try {
    $releaseSpec = Get-Content -LiteralPath 'pubspec.yaml' -Raw
    $releaseMatch = [regex]::Match($releaseSpec, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?)\+(\d+)\s*$')
    if (-not $releaseMatch.Success) { throw 'Use version: major.minor.patch+build in pubspec.yaml.' }
    $releaseVersion = $releaseMatch.Groups[1].Value
    $releaseBuild = $releaseMatch.Groups[2].Value
    & (Join-Path $PSScriptRoot 'setup_release_signing.ps1')
    $releaseDart = @"
// Generated from pubspec.yaml by tool/build_release.ps1.
abstract final class AppVersion {
  static const name = 'Mahila Mitr';
  static const version = '$releaseVersion';
  static const build = $releaseBuild;
  static const display = 'Version `$version (build `$build)';
}
"@
    [IO.File]::WriteAllText((Join-Path $releaseRoot 'lib/app_version.dart'), $releaseDart)
    $releaseFlutterCommand = (Get-Command flutter -ErrorAction Stop).Source
    $releaseFlutterRoot = Split-Path (Split-Path $releaseFlutterCommand -Parent) -Parent
    $releaseDartExe = Join-Path $releaseFlutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
    $releaseFlutterSnapshot = Join-Path $releaseFlutterRoot 'bin/cache/flutter_tools.snapshot'
    if ((Test-Path -LiteralPath $releaseDartExe) -and (Test-Path -LiteralPath $releaseFlutterSnapshot)) {
        & $releaseDartExe $releaseFlutterSnapshot build apk --release --build-name $releaseVersion --build-number $releaseBuild
    } else {
        & $releaseFlutterCommand build apk --release --build-name $releaseVersion --build-number $releaseBuild
    }
    if ($LASTEXITCODE -ne 0) { throw 'Flutter release build failed.' }
    $releaseFolder = Join-Path $releaseRoot "build/releases/mahila-mitr/$releaseVersion+$releaseBuild"
    New-Item -ItemType Directory -Path $releaseFolder -Force | Out-Null
    $releaseApk = Join-Path $releaseFolder 'mahila-mitr.apk'
    Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' -Destination $releaseApk
    $releaseHash = (Get-FileHash -LiteralPath $releaseApk -Algorithm SHA256).Hash.ToLowerInvariant()
    "$releaseHash  mahila-mitr.apk" | Set-Content -LiteralPath (Join-Path $releaseFolder 'SHA256SUMS.txt')
    [ordered]@{
        name = 'mahila-mitr'; displayName = 'Mahila Mitr'; version = $releaseVersion
        buildNumber = [int]$releaseBuild; buildType = 'release'; platform = 'android'
        applicationId = 'com.example.mahila_mitr'; file = 'mahila-mitr.apk'; sha256 = $releaseHash
        sizeBytes = (Get-Item -LiteralPath $releaseApk).Length
        builtAtUtc = [DateTime]::UtcNow.ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $releaseFolder 'release-info.json')
    Write-Output "Release APK: $releaseApk"
} finally { Pop-Location }
