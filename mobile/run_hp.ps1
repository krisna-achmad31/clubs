# Analyze, build debug APK, install & launch on the connected Infinix.
$ErrorActionPreference = 'Stop'
$env:PUB_CACHE = 'D:\flutter_pub_cache'
Set-Location $PSScriptRoot
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$device = '1215125453004629'

Write-Host '== flutter analyze ==' -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) { Write-Host 'Analyze gagal, berhenti.' -ForegroundColor Red; exit 1 }

Write-Host '== flutter build apk --debug ==' -ForegroundColor Cyan
flutter build apk --debug
if ($LASTEXITCODE -ne 0) { Write-Host 'Build gagal.' -ForegroundColor Red; exit 1 }

Write-Host '== install & launch ==' -ForegroundColor Cyan
& $adb -s $device install -r build\app\outputs\flutter-apk\app-debug.apk
& $adb -s $device shell monkey -p id.klubby.app -c android.intent.category.LAUNCHER 1
Write-Host 'SELESAI - app sudah jalan di HP' -ForegroundColor Green
