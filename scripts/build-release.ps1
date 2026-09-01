<#
.SYNOPSIS
Builds a release APK for the Flutter Delivery App.

.DESCRIPTION
This script safely automates the process of fetching dependencies, 
analyzing the codebase for errors, and compiling a release APK.
It expects you to provide the production API keys, or it will use the ones 
hardcoded as defaults in env.dart.

.EXAMPLE
.\build-release.ps1 -MapboxToken "pk.123" -ClerkApi "https://prod-clerk" -ConvexApi "https://prod-convex.site"
#>

param (
    [string]$MapboxToken = "",
    [string]$ClerkApi = "",
    [string]$ConvexApi = ""
)

Write-Host "========================================="
Write-Host "🚀 Starting Flutter Release Build"
Write-Host "========================================="

# 1. Fetch Dependencies
Write-Host "`n[1/4] Fetching dependencies..."
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Error "flutter pub get failed."
    exit $LASTEXITCODE
}

# 2. Analyze
Write-Host "`n[2/4] Analyzing Dart code..."
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Error "flutter analyze found issues. Please fix them before releasing."
    exit $LASTEXITCODE
}

# 3. Build Command Construction
Write-Host "`n[3/4] Building APK..."
$BuildCommand = "flutter build apk --release"

if ($MapboxToken -ne "") {
    $BuildCommand += " --dart-define=MAPBOX_ACCESS_TOKEN=$MapboxToken"
}
if ($ClerkApi -ne "") {
    $BuildCommand += " --dart-define=CLERK_FRONTEND_API=$ClerkApi"
}
if ($ConvexApi -ne "") {
    $BuildCommand += " --dart-define=CONVEX_HTTP_URL=$ConvexApi"
}

Invoke-Expression $BuildCommand
if ($LASTEXITCODE -ne 0) {
    Write-Error "APK Build failed."
    exit $LASTEXITCODE
}

# 4. Success
Write-Host "`n[4/4] Build Successful! 🎉"
Write-Host "Your release APK is located at: build\app\outputs\flutter-apk\app-release.apk"
Write-Host "========================================="
