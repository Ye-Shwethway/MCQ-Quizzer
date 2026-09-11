[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments)][string[]]$FlutterArguments)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$pin = Get-Content -LiteralPath (Join-Path $projectRoot 'flutter-toolchain.json') -Raw | ConvertFrom-Json
$sdkRevision = & git -C $pin.sdkPath rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $sdkRevision -ne $pin.revision) {
    throw 'Pinned Flutter SDK is missing or has changed. Restore the revision in flutter-toolchain.json.'
}
Push-Location -LiteralPath $projectRoot
try {
    & (Join-Path $pin.sdkPath 'bin/flutter.bat') @FlutterArguments
    $resultCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $resultCode
