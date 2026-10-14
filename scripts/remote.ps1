# Runs on the x86 Windows PC after the tree is at C:\chow\src.
# Usage: remote.ps1 -Ref 3.47.5 windows-x64 linux-x64
param(
  [string]$Ref = 'stable',
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Targets
)
$ErrorActionPreference = 'Stop'
if (-not $Targets -or $Targets.Count -eq 0) { $Targets = @('windows-x64') }
$src = 'C:\chow\src'
$flutter = Join-Path $env:USERPROFILE 'flutter'
$built = @()

function Ensure-Flutter {
  if (-not (Test-Path (Join-Path $flutter 'bin\flutter.bat'))) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
      throw 'git is not installed on this PC'
    }
    & git clone --depth 1 --branch $Ref https://github.com/flutter/flutter.git $flutter
    if (-not $?) {
      if (Test-Path $flutter) { Remove-Item -Recurse -Force $flutter }
      & git clone --depth 1 --branch stable https://github.com/flutter/flutter.git $flutter
    }
  }
  $env:Path = (Join-Path $flutter 'bin') + ';' + $env:Path
  & flutter.bat config --no-analytics --enable-windows-desktop | Out-Null
}

function Build-WindowsX64 {
  $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
  $cl = $null
  if (Test-Path $vswhere) {
    $cl = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find 'VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe' | Select-Object -First 1
  }
  if (-not $cl) {
    throw 'This PC needs Visual Studio 2022 Build Tools with the x64 C++ workload'
  }
  Ensure-Flutter
  Set-Location $src
  & flutter.bat build windows --release --dart-define=AUTH_API=https://gno.money
  if (-not $?) { throw 'flutter build windows failed' }
  $script:built += 'windows-x64'
}

function Build-LinuxX64 {
  wsl -e true 2>$null
  if (-not $?) {
    throw 'linux-x64 on this PC needs WSL. In an admin PowerShell: wsl --install -d Ubuntu'
  }
  $cmd = "export CHOW_FLUTTER_REF='$Ref'; export CHOW_PUBLISH=/mnt/c/chow/src/build/linux; bash /mnt/c/chow/src/scripts/remote.sh"
  wsl -e bash -lc $cmd
  if (-not $?) { throw 'flutter build linux in WSL failed' }
  $script:built += 'linux-x64'
}

foreach ($t in $Targets) {
  switch ($t) {
    'windows-x64' { Build-WindowsX64 }
    'linux-x64' { Build-LinuxX64 }
    default { throw "unknown target $t" }
  }
}
Write-Output ("CHOW_BUILT " + ($built -join ' '))
