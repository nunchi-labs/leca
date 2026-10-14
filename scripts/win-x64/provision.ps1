# Installed by autounattend on first logon, then again after each reboot until C:\chow\ready exists.
$ErrorActionPreference = 'Continue'
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
  exit 0
}
New-Item -ItemType Directory -Force -Path C:\chow | Out-Null
$log = 'C:\chow\provision.log'
function Log($msg) {
  $line = "$(Get-Date -Format o) $msg"
  Add-Content -Path $log -Value $line
  Write-Output $line
}

$here = $PSCommandPath
$installed = 'C:\chow\provision.ps1'
if ($here -and $here -ne $installed -and (Test-Path $here)) {
  Copy-Item $here $installed -Force
}
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-ExecutionPolicy Bypass -File C:\chow\provision.ps1'
$trigger = New-ScheduledTaskTrigger -AtLogOn -User chow
Register-ScheduledTask -TaskName ChowProvision -Action $action -Trigger $trigger -User chow -RunLevel Highest -Force | Out-Null

New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name AllowDevelopmentWithoutDevLicense -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -PropertyType DWord -Value 1 -Force | Out-Null
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name NoAutoRebootWithLoggedOnUsers -PropertyType DWord -Value 1 -Force | Out-Null
Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Set-Service -Name UsoSvc -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service -Name UsoSvc -Force -ErrorAction SilentlyContinue

if (Test-Path C:\chow\ready) { exit 0 }
Log 'provision start'

foreach ($d in 'D','E','F','G') {
  $inf = "${d}:\NetKVM\w11\amd64\netkvm.inf"
  if (Test-Path $inf) {
    Log "install $inf"
    pnputil /add-driver $inf /install
  }
}

for ($i = 0; $i -lt 30; $i++) {
  try {
    Invoke-WebRequest -Uri https://github.com -UseBasicParsing -TimeoutSec 8 | Out-Null
    break
  } catch {
    Start-Sleep 2
  }
}

$cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' | Select-Object -First 1
if ($cap -and $cap.State -ne 'Installed') {
  Log 'install OpenSSH server'
  Add-WindowsCapability -Online -Name $cap.Name | Out-Null
}
Set-Service -Name sshd -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service sshd -ErrorAction SilentlyContinue
if (-not (Get-NetFirewallRule -Name sshd -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}

foreach ($d in 'D','E','F','G') {
  $p = "${d}:\id_ed25519.pub"
  if (Test-Path $p) {
    $auth = 'C:\ProgramData\ssh\administrators_authorized_keys'
    Set-Content -Path $auth -Value ((Get-Content $p -Raw).Trim()) -Encoding ascii
    icacls $auth /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
    Log 'ssh key installed'
    break
  }
}

$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Log 'install git'
  winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
}

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$cl = $null
if (Test-Path $vswhere) {
  $cl = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find 'VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe' | Select-Object -First 1
}
if (-not $cl) {
  Log 'install Visual Studio Build Tools'
  $setup = 'C:\chow\vs_buildtools.exe'
  if (-not (Test-Path $setup)) {
    Invoke-WebRequest -Uri https://aka.ms/vs/17/release/vs_buildtools.exe -OutFile $setup
  }
  $proc = Start-Process -FilePath $setup -ArgumentList @(
    '--quiet','--wait','--norestart',
    '--add','Microsoft.VisualStudio.Workload.VCTools',
    '--add','Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
    '--includeRecommended'
  ) -Wait -PassThru
  Log "vs_buildtools exit $($proc.ExitCode)"
}

$ref = 'stable'
foreach ($d in 'D','E','F','G') {
  $p = "${d}:\flutter.ref"
  if (Test-Path $p) { $ref = (Get-Content $p -Raw).Trim(); break }
}
if (-not (Test-Path C:\flutter\bin\flutter.bat)) {
  Log "clone flutter $ref"
  & git clone --depth 1 --branch $ref https://github.com/flutter/flutter.git C:\flutter
  if (-not $?) {
    if (Test-Path C:\flutter) { Remove-Item -Recurse -Force C:\flutter }
    & git clone --depth 1 --branch stable https://github.com/flutter/flutter.git C:\flutter
  }
}
$env:Path = 'C:\flutter\bin;' + $env:Path
# A shallow clone plus `git fetch --tags` downloads the entire Flutter history
# and stalls the first command. The version check skips the fetch for three days
# when this stamp is already present.
New-Item -ItemType Directory -Force -Path C:\flutter\bin\cache | Out-Null
$checked = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.000000')
@"
{
  "lastTimeVersionWasChecked": "$checked"
}
"@ | Set-Content -Path C:\flutter\bin\cache\flutter_version_check.stamp -Encoding ascii
Log 'flutter precache'
& flutter.bat config --no-analytics --enable-windows-desktop
& flutter.bat precache --windows
if (-not (Test-Path C:\flutter\bin\flutter.bat)) {
  Log 'flutter missing, not ready'
  exit 1
}

Set-Content -Path C:\chow\ready -Value 'ok'
Log 'provision done'
