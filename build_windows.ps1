# Windows Build Script for Coriander Player

param (
    [string]$BuildMode = "Release",
    [switch]$SkipPubGet = $false
)

$ErrorActionPreference = "Stop"

Write-Host "Starting build process..." -ForegroundColor Green

# Interactive Mode Selection (if not running with parameters)
if ($PSBoundParameters.Count -eq 0) {
    Write-Host "Select Build Mode:" -ForegroundColor Yellow
    Write-Host "1. Release (Optimized, Slower build) [Default]"
    Write-Host "2. Debug (Unoptimized, Faster build)"
    
    # Wait for input with timeout (default to Release)
    $selection = 1
    if ($Host.UI.RawUI.KeyAvailable) {
        $selection = Read-Host "Enter number (1/2)"
    }
    else {
        Write-Host "Waiting 3 seconds for input... (Press any key to interrupt)" -NoNewline
        $timeout = 30
        while ($timeout -gt 0) {
            if ($Host.UI.RawUI.KeyAvailable) {
                Write-Host ""
                $selection = Read-Host "Enter number (1/2)"
                break
            }
            Start-Sleep -Milliseconds 100
            $timeout--
        }
        Write-Host ""
    }

    if ($selection -eq "2") {
        $BuildMode = "Debug"
    }
}

Write-Host "Selected Build Mode: $BuildMode" -ForegroundColor Cyan

# Check if flutter is available
if (-not (Get-Command "flutter" -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter command not found. Please ensure Flutter is installed and in your PATH."
    Read-Host "Press Enter to exit..."
    exit 1
}

# 1. Smart flutter pub get
$needPubGet = $true
if ($SkipPubGet) {
    $needPubGet = $false
}
elseif (Test-Path "pubspec.lock") {
    $yamlTime = (Get-Item "pubspec.yaml").LastWriteTime
    $lockTime = (Get-Item "pubspec.lock").LastWriteTime
    if ($yamlTime -le $lockTime) {
        $needPubGet = $false
    }
}

if ($needPubGet) {
    Write-Host "Running flutter pub get..." -ForegroundColor Cyan
    flutter pub get
}
else {
    Write-Host "Skipping flutter pub get (dependencies are up to date)." -ForegroundColor Gray
}

# 2. Pre-build: Copy app icon to resources
$appIconSource = "app_icon.ico"
$appIconResourceDest = "windows\runner\resources\app_icon.ico"
if (Test-Path $appIconSource) {
    Write-Host "Updating application icon ($appIconResourceDest)..." -ForegroundColor Cyan
    Copy-Item -Path $appIconSource -Destination $appIconResourceDest -Force
}
else {
    Write-Warning "app_icon.ico not found in project root. The application icon might be default."
}

# 3. Build Windows
Write-Host "Building Windows ($BuildMode)..." -ForegroundColor Cyan
# Convert mode to lowercase for flutter command
$flutterMode = $BuildMode.ToLower()
flutter build windows --$flutterMode

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed!"
    Read-Host "Press Enter to exit..."
    exit 1
}

# 4. Post-build: Copy resources
$buildDir = "build\windows\x64\runner\$BuildMode"
$bassSrcDir = "BASS"
$bassDestDir = Join-Path $buildDir "BASS"

# Ensure output directory exists (it should after build)
if (-not (Test-Path $buildDir)) {
    Write-Error "Build directory not found: $buildDir"
    Read-Host "Press Enter to exit..."
    exit 1
}

# Copy BASS DLLs if source exists
if (Test-Path $bassSrcDir) {
    Write-Host "Copying BASS DLLs from $bassSrcDir to $bassDestDir..." -ForegroundColor Cyan
    if (-not (Test-Path $bassDestDir)) {
        New-Item -ItemType Directory -Force -Path $bassDestDir | Out-Null
    }
    Copy-Item -Path "$bassSrcDir\*" -Destination $bassDestDir -Recurse -Force

    # Verify all required BASS DLLs are in the destination
    $requiredDLLs = @("bass.dll", "basswasapi.dll", "bass_fx.dll")
    $missingDLLs = @()
    
    foreach ($dll in $requiredDLLs) {
        if (-not (Test-Path "$bassDestDir\$dll")) {
            $missingDLLs += $dll
            Write-Warning "$dll not found in output directory!"
        }
    }
    
    if ($missingDLLs.Count -gt 0) {
        Write-Error "Missing BASS DLLs: $($missingDLLs -join ', ')`nPlease check if they exist in source BASS folder: $bassSrcDir"
        Read-Host "Press Enter to exit..."
        exit 1
    }
    else {
        Write-Host "All required BASS DLLs copied successfully: $($requiredDLLs -join ', ')" -ForegroundColor Green
    }
}
else {
    Write-Error "BASS directory not found in project root ($bassSrcDir)."
    Write-Error "The application cannot play audio without bass.dll, basswasapi.dll and bass_fx.dll."
    Write-Error "Please create a 'BASS' folder in the project root and place the DLLs there, then run this script again."
    Read-Host "Press Enter to exit..."
    exit 1
}

# Copy desktop_lyric
$desktopLyricSrc = "desktop_lyric"
$desktopLyricDest = Join-Path $buildDir "desktop_lyric"
if (Test-Path $desktopLyricSrc) {
    Write-Host "Copying desktop_lyric from $desktopLyricSrc to $desktopLyricDest..." -ForegroundColor Cyan
    if (-not (Test-Path $desktopLyricDest)) {
        New-Item -ItemType Directory -Force -Path $desktopLyricDest | Out-Null
    }
    Copy-Item -Path "$desktopLyricSrc\*" -Destination $desktopLyricDest -Recurse -Force
    Write-Host "desktop_lyric copied successfully." -ForegroundColor Green
}
else {
    Write-Warning "desktop_lyric directory not found in project root ($desktopLyricSrc)!"
}

# 5. Post-build: Copy app icon (to output folder, for runtime use if needed)
$appIconDest = Join-Path $buildDir "app_icon.ico"

if (Test-Path $appIconSource) {
    Write-Host "Copying app_icon.ico to $appIconDest..." -ForegroundColor Cyan
    Copy-Item -Path $appIconSource -Destination $appIconDest -Force
    Write-Host "app_icon.ico copied successfully." -ForegroundColor Green
}
else {
    Write-Warning "app_icon.ico not found in project root ($appIconSource)."
    Write-Warning "The executable will not have a custom icon."
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "Executable is located at: $(Join-Path (Get-Location) $buildDir)" -ForegroundColor Yellow
Write-Host "  - Main: coriander_player.exe"
Write-Host "  - Dependencies: BASS/*.dll, desktop_lyric/"
Write-Host "  - Icon: app_icon.ico`n" -ForegroundColor Yellow

Read-Host "Press Enter to exit..."
