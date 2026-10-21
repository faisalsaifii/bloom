# Builds Bloom for every platform that can be built from Windows.
# Usage: pwsh tools/build.ps1 [-Godot D:\godot-bin\Godot_v4.5.1-stable_win64_console.exe] [-Only windows,web]
param(
	[string]$Godot = "D:\godot-bin\Godot_v4.5.1-stable_win64_console.exe",
	[string]$Rcedit = "D:\godot-bin\tools\rcedit-x64.exe",
	[string[]]$Only = @("windows", "linux", "macos", "web", "android", "ios")
)
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType File -Force build\.gdignore | Out-Null

function Export($preset, $path) {
	New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
	Write-Host "==> $preset -> $path"
	& $Godot --headless --path . --export-release $preset $path 2>&1 | Where-Object { $_ -match "ERROR|WARNING|DONE" } | Select-Object -Last 6
}

& $Godot --headless --path . --import 2>&1 | Out-Null

if ($Only -contains "windows") {
	Export "Windows Desktop" "build/windows/Bloom.exe"
	if (Test-Path $Rcedit) {
		& $Rcedit build\windows\Bloom.exe --set-icon assets\branding\icon.ico `
			--set-version-string ProductName "Bloom" --set-version-string FileDescription "Bloom" `
			--set-version-string CompanyName "Bloom" --set-file-version 1.0.0.0 --set-product-version 1.0.0.0
	} else { Write-Warning "rcedit not found - exe keeps the default icon" }
}
if ($Only -contains "linux")   { Export "Linux" "build/linux/Bloom.x86_64" }
if ($Only -contains "macos")   { Export "macOS" "build/macos/Bloom.zip" }
if ($Only -contains "web")     { Export "Web" "build/web/index.html" }
if ($Only -contains "android") { Export "Android" "build/android/Bloom.apk" }
if ($Only -contains "ios")     { Export "iOS" "build/ios/Bloom.ipa" }
Write-Host "Done. Outputs are in build/"
