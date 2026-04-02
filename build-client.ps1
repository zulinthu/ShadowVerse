$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$vcvars = "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
$ninjaDir = "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"
$scopeLib = "C:\Program Files\Microsoft Visual Studio\2022\Professional\SDK\ScopeCppSDK\vc15\SDK\lib"
$libclangDir = "C:\Users\Administrator\AppData\Local\Programs\Python\Python313\Lib\site-packages\clang\native"
$cargoTarget = "C:\Users\Administrator\.codex\memories\shadowverse_target"
$ffmpegBin = "C:\ffmpeg\ffmpeg-8.0.1-essentials_build\bin"

cmd /c "\"$vcvars\" && set" | ForEach-Object {
  if ($_ -match "^(.*?)=(.*)$") {
    Set-Item -Path "env:$($matches[1])" -Value $matches[2]
  }
}

Remove-Item Env:CMAKE_GENERATOR_INSTANCE -ErrorAction SilentlyContinue
Remove-Item Env:CMAKE_GENERATOR_PLATFORM -ErrorAction SilentlyContinue
Remove-Item Env:CMAKE_GENERATOR_TOOLSET -ErrorAction SilentlyContinue
Remove-Item Env:WHISPER_DONT_GENERATE_BINDINGS -ErrorAction SilentlyContinue

$env:CARGO_TARGET_DIR = $cargoTarget
$env:LIBCLANG_PATH = $libclangDir
$env:CMAKE_GENERATOR = "Ninja"
$env:CMAKE_MAKE_PROGRAM = Join-Path $ninjaDir "ninja.exe"

if ($env:LIB) {
  $env:LIB = "$scopeLib;$env:LIB"
} else {
  $env:LIB = $scopeLib
}

if ($env:PATH -notlike "$ninjaDir*") {
  $env:PATH = "$ninjaDir;$env:PATH"
}

$srcTauri = Join-Path $projectRoot "src-tauri"
foreach ($exe in @("ffmpeg.exe", "ffplay.exe", "ffprobe.exe")) {
  $dst = Join-Path $srcTauri $exe
  if (!(Test-Path $dst)) {
    $src = Join-Path $ffmpegBin $exe
    if (Test-Path $src) {
      Copy-Item -LiteralPath $src -Destination $dst -Force
    }
  }
}

Set-Location $projectRoot
corepack yarn tauri build

$bundleSrc = Join-Path $cargoTarget "release\bundle"
$bundleDst = Join-Path $projectRoot "release\bundle"

if (!(Test-Path $bundleSrc)) {
  throw "Bundle output not found: $bundleSrc"
}

if (Test-Path $bundleDst) {
  Remove-Item -LiteralPath $bundleDst -Recurse -Force
}

New-Item -ItemType Directory -Path $bundleDst -Force | Out-Null
Copy-Item -Path (Join-Path $bundleSrc "*") -Destination $bundleDst -Recurse -Force

Write-Host ""
Write-Host "Bundle copied to: $bundleDst"
