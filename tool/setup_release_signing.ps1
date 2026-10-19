$ErrorActionPreference = 'Stop'
$releaseRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$releaseProperties = Join-Path $releaseRoot 'android/key.properties'
$releaseKeystore = Join-Path $releaseRoot 'android/app/mahila-mitr-release.keystore'
if (Test-Path -LiteralPath $releaseProperties) {
    Write-Output 'Existing release signing configuration retained.'
    return
}
if (Test-Path -LiteralPath $releaseKeystore) {
    throw 'The release keystore already exists. Restore its key.properties; do not replace the key.'
}
$releaseKeytool = 'C:/Program Files/Android/Android Studio/jbr/bin/keytool.exe'
if ($env:JAVA_HOME) {
    $releaseKeytool = Join-Path $env:JAVA_HOME 'bin/keytool.exe'
}
if (-not $env:JAVA_HOME -or -not (Test-Path -LiteralPath $releaseKeytool)) {
    $releaseKeytool = 'C:/Program Files/Android/Android Studio/jbr/bin/keytool.exe'
}
if (-not (Test-Path -LiteralPath $releaseKeytool)) {
    $releaseKeytool = (Get-Command keytool -ErrorAction Stop).Source
}
$releaseBytes = New-Object byte[] 32
$releaseRandom = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$releaseRandom.GetBytes($releaseBytes)
$releaseRandom.Dispose()
$releasePassword = [BitConverter]::ToString($releaseBytes).Replace('-', '')
$env:MM_RELEASE_SIGNING_PASSWORD = $releasePassword
try {
    & $releaseKeytool -genkeypair -keystore $releaseKeystore -storetype PKCS12 `
        -alias mahila-mitr-release -keyalg RSA -keysize 3072 -validity 10000 `
        -dname 'CN=Mahila Mitr' -storepass:env MM_RELEASE_SIGNING_PASSWORD `
        -keypass:env MM_RELEASE_SIGNING_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Release signing key creation failed.' }
    $releaseConfig = "storePassword=$releasePassword`nkeyPassword=$releasePassword`nkeyAlias=mahila-mitr-release`nstoreFile=mahila-mitr-release.keystore`n"
    [IO.File]::WriteAllText($releaseProperties, $releaseConfig)
    Write-Output 'Created dedicated release signing key and ignored local configuration.'
} finally {
    Remove-Item Env:MM_RELEASE_SIGNING_PASSWORD -ErrorAction SilentlyContinue
    $releasePassword = $null
    $releaseConfig = $null
}
