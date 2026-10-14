# Run once in an Administrator PowerShell on the x86 PC.
# Enables OpenSSH and accepts this Mac's build key.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' | Select-Object -First 1
if ($cap -and $cap.State -ne 'Installed') {
  Add-WindowsCapability -Online -Name $cap.Name | Out-Null
}
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd
if (-not (Get-NetFirewallRule -Name sshd -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}

$key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFigLNcGpzU40+owWiqS0fv8FdBrEi5VHng1ESf5LXVz chow-build'
$sshDir = Join-Path $env:USERPROFILE '.ssh'
New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
$auth = Join-Path $sshDir 'authorized_keys'
if (-not (Select-String -Path $auth -SimpleMatch $key -Quiet -ErrorAction SilentlyContinue)) {
  Add-Content -Path $auth -Value $key
}
icacls $auth /inheritance:r /grant "${env:USERNAME}:(F)" | Out-Null

$adminAuth = 'C:\ProgramData\ssh\administrators_authorized_keys'
New-Item -ItemType Directory -Force -Path 'C:\ProgramData\ssh' | Out-Null
if (-not (Select-String -Path $adminAuth -SimpleMatch $key -Quiet -ErrorAction SilentlyContinue)) {
  Add-Content -Path $adminAuth -Value $key
}
icacls $adminAuth /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
Write-Output 'sshd is up. From the Mac: ./build.sh x86'
