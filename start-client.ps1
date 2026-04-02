$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$vcvars = "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
$ninjaDir = "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"
$scopeLib = "C:\Program Files\Microsoft Visual Studio\2022\Professional\SDK\ScopeCppSDK\vc15\SDK\lib"
$libclangDir = "C:\Users\Administrator\AppData\Local\Programs\Python\Python313\Lib\site-packages\clang\native"
$cargoTarget = "C:\Users\Administrator\.codex\memories\shadowverse_target"
$ffmpegBin = "C:\ffmpeg\ffmpeg-8.0.1-essentials_build\bin"

if (!(Test-Path $vcvars)) {
  throw "Missing vcvars64.bat: $vcvars"
}

# Import MSVC build environment into current PowerShell session.
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

# Free stale Vite port if old dev process is still holding it.
$portPids = @()
$lines = cmd /c "netstat -ano | findstr :8054"
foreach ($line in $lines) {
  $parts = ($line -split "\s+") | Where-Object { $_ -ne "" }
  if ($parts.Count -ge 5) {
    $pidText = $parts[-1]
    if ($pidText -match "^\d+$") {
      $portPids += [int]$pidText
    }
  }
}
$portPids = $portPids | Select-Object -Unique
foreach ($p in $portPids) {
  if ($p -ne $PID) {
    Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
  }
}

Set-Location $projectRoot
corepack yarn tauri dev
