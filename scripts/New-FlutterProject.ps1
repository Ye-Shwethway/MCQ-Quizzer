# New projects only: resolve latest stable, install side-by-side, then pin it.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Destination,
    [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9_]*$')][string]$ProjectName,
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z][a-zA-Z0-9]*)+$')][string]$Organization,
    [string[]]$Packages = @(),
    [string]$SdkRoot = 'D:\FlutterSDKs'
)
$ErrorActionPreference = 'Stop'
foreach ($package in $Packages) {
    if ($package -notmatch '^[a-z][a-z0-9_]*$') { throw "Invalid package name: $package" }
}
$projectPath = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $projectPath) { throw 'Destination already exists. This command never upgrades or overwrites existing projects.' }
$remote = 'https://github.com/flutter/flutter.git'
$stable = & git ls-remote $remote refs/heads/stable
if ($LASTEXITCODE -ne 0 -or $stable -notmatch '^([0-9a-f]{40})\s+refs/heads/stable$') {
    throw 'Cannot verify official stable Flutter. No project was created.'
}
$revision = $Matches[1]
$sdkPath = Join-Path ([IO.Path]::GetFullPath($SdkRoot)) "flutter-stable-$($revision.Substring(0, 12))"
if (!(Test-Path -LiteralPath $sdkPath)) {
    & git -c core.longpaths=true clone --depth 1 --branch stable $remote $sdkPath
    if ($LASTEXITCODE -ne 0) { throw 'Flutter checkout failed; inspect the partial SDK directory before retrying.' }
}
$actualRevision = & git -C $sdkPath rev-parse HEAD
$actualRemote = & git -C $sdkPath remote get-url origin
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $revision -or $actualRemote -ne $remote) {
    throw 'SDK revision/origin mismatch. Existing SDK was not modified.'
}
$flutter = Join-Path $sdkPath 'bin\flutter.bat'
& $flutter --version
if ($LASTEXITCODE -ne 0) { throw 'SDK bootstrap failed. No project was created.' }
& $flutter create --platforms=android --org $Organization --project-name $ProjectName $projectPath
if ($LASTEXITCODE -ne 0) { throw 'Project creation failed; inspect the destination.' }
Push-Location -LiteralPath $projectPath
try {
    # Generated configuration belongs to this newly created project only.
    New-Item -ItemType Directory -Path '.vscode' -Force | Out-Null
    @{ 'dart.flutterSdkPath' = $sdkPath.Replace('\', '/') } | ConvertTo-Json | Set-Content -LiteralPath '.vscode/settings.json' -Encoding UTF8
    @{ revision = $revision; sdkPath = $sdkPath; channel = 'stable'; source = $remote } | ConvertTo-Json | Set-Content -LiteralPath 'flutter-toolchain.json' -Encoding UTF8
    if ($Packages.Count -gt 0) {
        & $flutter pub add @Packages
        if ($LASTEXITCODE -ne 0) { throw 'Requested plugins have no compatible resolution. Do not bypass the solver.' }
    }
    & $flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
    & $flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
    & $flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed. Plugin compatibility is not verified.' }
    Write-Host "Created and release-build verified: $projectPath (Flutter $revision). Commit pubspec.lock and flutter-toolchain.json."
} finally {
    Pop-Location
}
