# Windows Build Script for Coriander Player

$ErrorActionPreference = "Stop"

# Hardcode BuildMode to Release as requested
$BuildMode = "Release"
$finalOutputDir = "D:\All\Documents\Projects\coriander_player\output"

Write-Host "Starting build process (Release Mode)..." -ForegroundColor Green

# Check if flutter is available
if (-not (Get-Command "flutter" -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter command not found. Please ensure Flutter is installed and in your PATH."
    Read-Host "Press Enter to exit..."
    exit 1
}

# 1. Smart flutter pub get
$needPubGet = $true
$packageConfig = ".dart_tool\package_config.json"
if ((Test-Path "pubspec.lock") -and (Test-Path $packageConfig)) {
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
$flutterArgs = @("build", "windows", "--release")
if ($env:CPFEEDBACK_KEY) {
    Write-Host "Detected CPFEEDBACK_KEY in environment; enabling issue reporting." -ForegroundColor Gray
    $flutterArgs += "--dart-define=CPFEEDBACK_KEY=$($env:CPFEEDBACK_KEY)"
}
else {
    Write-Host "CPFEEDBACK_KEY not set; issue reporting will be disabled." -ForegroundColor Gray
}
flutter @flutterArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed!"
    Read-Host "Press Enter to exit..."
    exit 1
}

# 4. Prepare Output Directory
$buildDir = "build\windows\x64\runner\$BuildMode"

Write-Host "Preparing Output Directory: $finalOutputDir..." -ForegroundColor Cyan

# Check for running instance and kill it
$processName = "coriander_player"
if (Get-Process $processName -ErrorAction SilentlyContinue) {
    Write-Host "Stopping running instance of $processName..." -ForegroundColor Yellow
    Stop-Process -Name $processName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1 # Wait for file locks to release
}

if (Test-Path $finalOutputDir) {
    Remove-Item -Path $finalOutputDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $finalOutputDir | Out-Null

# 5. Copy Build Artifacts to Output Directory
Write-Host "Copying build artifacts to output directory..." -ForegroundColor Cyan
Copy-Item -Path "$buildDir\*" -Destination $finalOutputDir -Recurse -Force

# 6. Copy Additional Dependencies to Output Directory

# Copy BASS DLLs
$bassSrcDir = "BASS"
$bassDestDir = Join-Path $finalOutputDir "BASS"
if (Test-Path $bassSrcDir) {
    Write-Host "Copying BASS DLLs..." -ForegroundColor Cyan
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
}
else {
    Write-Error "BASS directory not found in project root ($bassSrcDir)."
    Write-Error "The application cannot play audio without bass.dll, basswasapi.dll and bass_fx.dll."
    Read-Host "Press Enter to exit..."
    exit 1
}

# Copy desktop_lyric
$desktopLyricSrc = "desktop_lyric"
$desktopLyricDest = Join-Path $finalOutputDir "desktop_lyric"
if (Test-Path $desktopLyricSrc) {
    Write-Host "Copying desktop_lyric..." -ForegroundColor Cyan
    if (-not (Test-Path $desktopLyricDest)) {
        New-Item -ItemType Directory -Force -Path $desktopLyricDest | Out-Null
    }
    Copy-Item -Path "$desktopLyricSrc\*" -Destination $desktopLyricDest -Recurse -Force
}
else {
    Write-Warning "desktop_lyric directory not found in project root ($desktopLyricSrc)!"
}

# Note: app_icon.ico is embedded in exe via Runner.rc during compilation
# No separate copy to output directory needed

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "All files have been output to: $finalOutputDir" -ForegroundColor Yellow
Write-Host "  - Main: coriander_player.exe (icon embedded via Runner.rc)"
Write-Host "  - Dependencies: BASS/*.dll, desktop_lyric/`n" -ForegroundColor Yellow

Read-Host "Press Enter to exit..."
