# Universal Flutter Build Script (Android & Windows)
# Drop this into any Flutter project root directory.

$ErrorActionPreference = "Stop"

# 1. Resolve project root and read pubspec.yaml dynamically
$rootDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$pubspecPath = Join-Path $rootDir "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    Write-Host "ERROR: pubspec.yaml not found at $pubspecPath" -ForegroundColor Red
    exit 1
}

$nameLine = Get-Content $pubspecPath | Where-Object { $_ -match "^name:\s*(.+)$" } | Select-Object -First 1
if (-not $nameLine) {
    Write-Host "ERROR: Could not find 'name:' field in pubspec.yaml." -ForegroundColor Red
    exit 1
}

$appName = ($nameLine -split "name:")[1].Trim()
$dateStr = Get-Date -Format "yyyy-MM-dd"

# -------------------------------------------------------------
# Helpers
# -------------------------------------------------------------
function Get-WindowsReleaseDir {
    $possibleDirs = @(
        (Join-Path $rootDir "build\windows\x64\runner\Release"),
        (Join-Path $rootDir "build\windows\runner\Release")
    )
    foreach ($d in $possibleDirs) {
        if (Test-Path $d) { return $d }
    }
    return $null
}

function Get-AndroidReleaseDir {
    $apkDir = Join-Path $rootDir "build\app\outputs\flutter-apk"
    if (Test-Path $apkDir) { return $apkDir }
    return $null
}

function Get-ExistingApk {
    $apkDir = Join-Path $rootDir "build\app\outputs\flutter-apk"
    $targetApkPath = Join-Path $apkDir "$appName-$dateStr-release-build.apk"
    $defaultApkPath = Join-Path $apkDir "app-release.apk"

    if (Test-Path $targetApkPath) { return $targetApkPath }
    if (Test-Path $defaultApkPath) { return $defaultApkPath }
    if (Test-Path $apkDir) {
        $found = Get-ChildItem -Path $apkDir -Filter "*.apk" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Open-InExplorer([string]$path) {
    if (-not (Test-Path $path)) {
        Write-Host "Path does not exist: $path" -ForegroundColor Yellow
        return
    }
    if ((Get-Item $path) -is [System.IO.DirectoryInfo]) {
        Start-Process explorer.exe -ArgumentList "`"$path`""
    } else {
        Start-Process explorer.exe -ArgumentList "/select,`"$path`""
    }
}

# -------------------------------------------------------------
# 2. Main Menu
# -------------------------------------------------------------
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Flutter Build Assistant: $appName" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Select action:"
Write-Host "  1) Android (Build APK)"
Write-Host "  2) Windows (Build Release exe)"
Write-Host "  3) Both (Build Android + Windows)"
Write-Host "  4) Open Existing Output Folder / Send APK"
$choice = Read-Host "Enter choice (1/2/3/4) [Default: 1]"
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }

# -------------------------------------------------------------
# Option 4: Quick Open / Send for Existing Builds
# -------------------------------------------------------------
if ($choice -eq "4") {
    Write-Host "`nSelect platform output to open:" -ForegroundColor Cyan
    Write-Host "  1) Android APK Output Folder / ADB Send"
    Write-Host "  2) Windows Release Output Folder"
    Write-Host "  3) Both Output Folders"
    $subChoice = Read-Host "Enter choice (1/2/3) [Default: 1]"
    if ([string]::IsNullOrWhiteSpace($subChoice)) { $subChoice = "1" }

    if ($subChoice -eq "1" -or $subChoice -eq "3") {
        $apkFile = Get-ExistingApk
        $apkDir = Get-AndroidReleaseDir
        if ($apkFile) {
            Write-Host "`nAndroid APK: $apkFile" -ForegroundColor Green
            $action = Read-Host "Action for APK? [S]end to phone via ADB / [O]pen output folder / [S]kip (s/o/skip) [Default: s]"
            if ([string]::IsNullOrWhiteSpace($action) -or $action -match "^[sS]$") {
                Send-AdbApk -apkPath $apkFile
            } elseif ($action -match "^[oO]$") {
                Write-Host "Opening Android output folder in Explorer..." -ForegroundColor Cyan
                Open-InExplorer $apkFile
            }
        } elseif ($apkDir) {
            Write-Host "`nOpening Android output folder: $apkDir" -ForegroundColor Cyan
            Open-InExplorer $apkDir
        } else {
            Write-Host "`nNo Android build output found." -ForegroundColor Yellow
        }
    }

    if ($subChoice -eq "2" -or $subChoice -eq "3") {
        $winDir = Get-WindowsReleaseDir
        if ($winDir) {
            $foundExe = Get-ChildItem -Path $winDir -Filter "*.exe" | Select-Object -First 1
            $target = if ($foundExe) { $foundExe.FullName } else { $winDir }
            Write-Host "`nOpening Windows output folder in Explorer: $winDir" -ForegroundColor Cyan
            Open-InExplorer $target
        } else {
            Write-Host "`nNo Windows build output found." -ForegroundColor Yellow
        }
    }

    exit 0
}

# -------------------------------------------------------------
# ADB Push Helper
# -------------------------------------------------------------
function Send-AdbApk([string]$apkPath) {
    while ($true) {
        Write-Host "Checking for ADB devices..." -ForegroundColor Cyan
        $devices = adb devices | Where-Object { $_ -match "\tdevice$" }
        if (-not $devices) {
            Write-Host "WARNING: No authorized ADB device found. Connect phone & enable USB debugging." -ForegroundColor Yellow
            $retry = Read-Host "Retry push? (y/n) [Default: y]"
            if ($retry -match "^[nN]$") {
                Write-Host "Skipped phone transfer." -ForegroundColor Yellow
                break
            }
            continue
        }

        Write-Host "Pushing APK to phone (/sdcard/Download/)..." -ForegroundColor Cyan
        adb push "$apkPath" /sdcard/Download/
        if ($LASTEXITCODE -eq 0) {
            Write-Host "SUCCESS: APK pushed to /sdcard/Download/" -ForegroundColor Green
            break
        } else {
            Write-Host "ERROR: adb push failed." -ForegroundColor Red
            $retry = Read-Host "Retry push? (y/n) [Default: y]"
            if ($retry -match "^[nN]$") { break }
        }
    }
}

# -------------------------------------------------------------
# Function: Handle Android Build
# -------------------------------------------------------------
function Process-Android {
    $apkDir = Join-Path $rootDir "build\app\outputs\flutter-apk"
    $newApkName = "$appName-$dateStr-release-build.apk"
    $targetApkPath = Join-Path $apkDir $newApkName
    $defaultApkPath = Join-Path $apkDir "app-release.apk"

    $existingApk = Get-ExistingApk
    $shouldBuild = $true

    if ($existingApk) {
        Write-Host "`nFound existing Android build: $existingApk" -ForegroundColor Yellow
        $useExisting = Read-Host "Use existing build without rebuilding? (y/n) [Default: n]"
        if ($useExisting -match "^[yY]$") {
            $shouldBuild = $false
            $targetApkPath = $existingApk
        }
    }

    if ($shouldBuild) {
        Write-Host "`nBuilding Android Release APK (arm64)..." -ForegroundColor Cyan
        flutter build apk --release --target-platform android-arm64
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Android build failed." -ForegroundColor Red
            return
        }

        if (Test-Path $defaultApkPath) {
            if (Test-Path $targetApkPath) {
                Remove-Item -Path $targetApkPath -Force -ErrorAction SilentlyContinue
            }
            Move-Item -Path $defaultApkPath -Destination $targetApkPath -Force
        }
    }

    Write-Host "`nSUCCESS: APK ready at $targetApkPath" -ForegroundColor Green

    # Post-build options: Send (default) / Open folder in Explorer / None
    $action = Read-Host "`nAction for Android? [S]end to phone via ADB / [O]pen APK folder in Explorer / [N]one (s/o/n) [Default: s]"
    if ([string]::IsNullOrWhiteSpace($action) -or $action -match "^[sS]$") {
        Send-AdbApk -apkPath $targetApkPath
    } elseif ($action -match "^[oO]$") {
        Write-Host "Opening Android output folder in Explorer..." -ForegroundColor Cyan
        Open-InExplorer $targetApkPath
    }
}

# -------------------------------------------------------------
# Function: Handle Windows Build
# -------------------------------------------------------------
function Process-Windows {
    $winDir = Get-WindowsReleaseDir
    $existingExe = $null
    if ($winDir) {
        $foundExe = Get-ChildItem -Path $winDir -Filter "*.exe" | Select-Object -First 1
        if ($foundExe) { $existingExe = $foundExe.FullName }
    }

    $shouldBuild = $true
    if ($existingExe) {
        Write-Host "`nFound existing Windows build: $existingExe" -ForegroundColor Yellow
        $useExisting = Read-Host "Use existing build without rebuilding? (y/n) [Default: n]"
        if ($useExisting -match "^[yY]$") {
            $shouldBuild = $false
        }
    }

    if ($shouldBuild) {
        Write-Host "`nBuilding Windows Release Application..." -ForegroundColor Cyan
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Windows build failed." -ForegroundColor Red
            return
        }

        $winDir = Get-WindowsReleaseDir
        if ($winDir) {
            $foundExe = Get-ChildItem -Path $winDir -Filter "*.exe" | Select-Object -First 1
            if ($foundExe) { $existingExe = $foundExe.FullName }
        }
    }

    Write-Host "`nSUCCESS: Windows Release build ready in $winDir" -ForegroundColor Green

    $openFolder = Read-Host "`nOpen Windows output folder in Explorer? (y/n) [Default: y]"
    if ([string]::IsNullOrWhiteSpace($openFolder) -or $openFolder -match "^[yY]$") {
        $target = if ($existingExe) { $existingExe } else { $winDir }
        Write-Host "Opening Windows output folder in Explorer: $winDir" -ForegroundColor Cyan
        Open-InExplorer $target
    }
}

# Execute build choices
$buildAndroid = ($choice -eq "1" -or $choice -eq "3")
$buildWindows = ($choice -eq "2" -or $choice -eq "3")

if ($buildAndroid) { Process-Android }
if ($buildWindows) { Process-Windows }

Write-Host "`nAll operations completed." -ForegroundColor Green
