#!/bin/bash
# Windows x64 build on the Omarchy PC, inside a KVM guest.
# The disk, ISO, and keys stay in ~/.cache/leca/windows-x64.
set -euo pipefail

ref="${LECA_FLUTTER_REF:-stable}"
src="${LECA_SRC:-$HOME/leca}"
cache="${LECA_WIN_CACHE:-$HOME/.cache/leca/windows-x64}"
mem="${LECA_WIN_MEM:-32G}"
cpus="${LECA_WIN_CPUS:-8}"
port="${LECA_WIN_PORT:-2224}"
iso_url="https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENT_CONSUMER_x64fre_en-us.iso"
iso_bytes=7736125440
here="$(cd "$(dirname "$0")" && pwd)"
code="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
vars_src="/usr/share/edk2/x64/OVMF_VARS.4m.fd"

say() { echo "win-x64: $*"; }

as_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    "$@"
    return
  fi
  if [[ -z ${LECA_SUDO_PASSWORD:-} ]]; then
    sudo -n "$@"
    return
  fi
  echo "$LECA_SUDO_PASSWORD" | sudo -S -p '' "$@"
}

ensure_host() {
  if [[ ! -e /dev/kvm ]]; then
    echo "win-x64: /dev/kvm is missing" >&2
    exit 1
  fi
  if ! command -v qemu-system-x86_64 >/dev/null || ! command -v qemu-img >/dev/null || ! command -v mkisofs >/dev/null; then
    as_root pacman -S --noconfirm --needed qemu-system-x86 qemu-img edk2-ovmf cdrtools
  fi
  [[ -f $code && -f $vars_src ]] || { echo "win-x64: OVMF firmware is missing" >&2; exit 1; }
  mkdir -p "$cache"
  if [[ ! -f $cache/id_ed25519 ]]; then
    ssh-keygen -t ed25519 -N "" -f "$cache/id_ed25519" -C leca-win-x64 >/dev/null
  fi
  if [[ ! -f $cache/efi-vars.fd ]]; then
    cp "$vars_src" "$cache/efi-vars.fd"
  fi
  if [[ ! -f $cache/disk.qcow2 ]]; then
    qemu-img create -f qcow2 "$cache/disk.qcow2" 80G >/dev/null
  fi
}

wait_iso() {
  local dest="$cache/windows.iso" partial="$cache/windows.iso.partial" pid=""
  if [[ -f $dest ]] && [[ $(stat -c%s "$dest") -eq $iso_bytes ]]; then
    return
  fi
  if [[ -f $cache/download.pid ]]; then
    pid="$(cat "$cache/download.pid" 2>/dev/null || true)"
  fi
  if [[ -n ${pid:-} ]] && kill -0 "$pid" 2>/dev/null; then
    say "waiting for the Windows ISO download"
    while kill -0 "$pid" 2>/dev/null; do
      if [[ -f $partial ]]; then
        say "ISO $(stat -c%s "$partial") / $iso_bytes"
      fi
      sleep 20
    done
  fi
  if [[ -f $partial ]] && [[ $(stat -c%s "$partial") -eq $iso_bytes ]]; then
    mv "$partial" "$dest"
    return
  fi
  if [[ ! -f $dest ]] || [[ $(stat -c%s "$dest") -ne $iso_bytes ]]; then
    say "downloading the Windows ISO"
    curl -fL --retry 8 --retry-all-errors -C - -o "$partial" "$iso_url"
    mv "$partial" "$dest"
  fi
  [[ $(stat -c%s "$dest") -eq $iso_bytes ]] || { echo "win-x64: ISO is the wrong size" >&2; exit 1; }
}

write_seed() {
  local seed="$cache/seed"
  mkdir -p "$seed"
  cp "$here/win-x64/autounattend.xml" "$seed/autounattend.xml"
  cp "$here/win-x64/provision.ps1" "$seed/provision.ps1"
  cp "$cache/id_ed25519.pub" "$seed/id_ed25519.pub"
  echo "$ref" >"$seed/flutter.ref"
  (
    cd "$seed"
    mkisofs -output "$cache/seed.iso" -volid LECASEED -joliet -rock -quiet \
      autounattend.xml provision.ps1 id_ed25519.pub flutter.ref
  )
}

vm_pid() {
  [[ -f $cache/qemu.pid ]] || return 1
  local pid
  pid="$(cat "$cache/qemu.pid")"
  kill -0 "$pid" 2>/dev/null || return 1
  echo "$pid"
}

guest() {
  ssh -i "$cache/id_ed25519" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile="$cache/known_hosts" \
    -o ConnectTimeout=10 \
    -o LogLevel=ERROR \
    -p "$port" \
    leca@127.0.0.1 "$@"
}

ssh_ok() { guest echo ok >/dev/null 2>&1; }

# `if exist ... exit 0 else exit 1` is true when the file is missing.
# cmd only attaches else to a parenthesized block, and that form still
# goes wrong once OpenSSH wraps the line in another cmd /c.
windows_ready() {
  guest 'type C:\leca\ready' >/dev/null 2>&1
}

vm_mem_matches() {
  local pid got
  pid="$(vm_pid || true)"
  [[ -n ${pid:-} ]] || return 1
  got="$(tr '\0' '\n' <"/proc/$pid/cmdline" | awk 'prev=="-m" { print; exit } { prev=$0 }')"
  [[ $got == "$mem" ]]
}

# OVMF times out when it starts setup from the Windows DVD. A small FAT disk
# with the EFI loader and boot.wim starts, and setup reads install.wim from the DVD.
prepare_bootdisk() {
  local img="$cache/boot.img"
  [[ -f $cache/boot.ready ]] && return 0
  rm -f "$img"
  say "building a FAT boot disk for Windows setup"
  local mntiso="$cache/mnt-iso" mntboot="$cache/mnt-boot"
  mkdir -p "$mntiso" "$mntboot"
  if ! mountpoint -q "$mntiso"; then
    as_root mount -o loop,ro "$cache/windows.iso" "$mntiso"
  fi
  local bytes=$(( $(stat -c%s "$mntiso/sources/boot.wim") + 400 * 1024 * 1024 ))
  truncate -s "$bytes" "$img"
  printf 'label: dos\nstart=2048, type=ef, bootable\n' | sfdisk "$img" >/dev/null
  local loop
  loop="$(as_root losetup -Pf --show "$img" | tr -d '[:space:]')"
  as_root mkfs.fat -F 32 -n LECABOOT "${loop}p1"
  as_root mount "${loop}p1" "$mntboot"
  as_root mkdir -p "$mntboot/EFI/BOOT" "$mntboot/sources" "$mntboot/boot"
  as_root cp "$mntiso/efi/boot/bootx64.efi" "$mntboot/EFI/BOOT/BOOTX64.EFI"
  as_root cp -r --no-preserve=ownership "$mntiso/efi/microsoft" "$mntboot/EFI/Microsoft"
  as_root cp -r --no-preserve=ownership "$mntiso/boot/." "$mntboot/boot/"
  as_root cp "$mntiso/bootmgr.efi" "$mntboot/bootmgr.efi"
  as_root cp "$mntiso/sources/boot.wim" "$mntboot/sources/boot.wim"
  as_root cp "$cache/seed/autounattend.xml" "$cache/seed/provision.ps1" \
    "$cache/seed/id_ed25519.pub" "$cache/seed/flutter.ref" "$mntboot/"
  sync
  as_root umount "$mntboot"
  as_root losetup -d "$loop"
  as_root umount "$mntiso" || true
  : >"$cache/boot.ready"
}

boot() {
  local with_iso=$1
  vm_pid >/dev/null && return 0
  # SeaBIOS. This ISO's boot catalog is a BIOS image, and Windows setup sees a
  # plain IDE disk. OVMF never got past the driver screen.
  local -a args=(
    qemu-system-x86_64
    -name leca-win-x64
    -machine "pc,accel=kvm"
    -cpu host
    -smp "$cpus"
    -m "$mem"
    -display none
    -device qemu-xhci
    -device usb-kbd
    -device usb-tablet
    -drive "if=none,id=system,format=qcow2,file=$cache/disk.qcow2"
    -device "ide-hd,drive=system,bus=ide.0,unit=0"
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${port}-:22"
    -device "e1000e,netdev=net0"
    -serial "file:$cache/serial.log"
    -monitor "unix:$cache/monitor.sock,server,nowait"
    -pidfile "$cache/qemu.pid"
    -daemonize
  )
  if [[ $with_iso == yes ]]; then
    args+=(
      -boot order=d
      -drive "if=none,id=install,media=cdrom,format=raw,readonly=on,file=$cache/windows.iso"
      -device "ide-cd,drive=install,bus=ide.0,unit=1"
      -drive "if=none,id=seed,media=cdrom,format=raw,readonly=on,file=$cache/seed.iso"
      -device "ide-cd,drive=seed,bus=ide.1"
    )
  else
    args+=(-boot order=c)
  fi
  "${args[@]}"
  # The DVD asks for a key. Answer it once. Later reboots time out and boot the disk.
  if [[ $with_iso == yes ]]; then
    python3 - "$cache/monitor.sock" <<'PY' &
import socket, sys, time
path = sys.argv[1]
time.sleep(3)
def send(cmd):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(2)
    s.connect(path)
    try:
        s.recv(16)
    except Exception:
        pass
    s.sendall((cmd + "\n").encode())
    s.close()
for _ in range(12):
    try:
        send("sendkey spc")
    except Exception:
        pass
    time.sleep(0.4)
PY
  fi
}

wait_ready() {
  local i
  for ((i = 0; i < 180; i++)); do
    if ssh_ok && windows_ready; then
      return 0
    fi
    if ((i % 2 == 0)); then
      say "still waiting for Windows provision ($((i / 2)) min)"
    fi
    sleep 30
  done
  echo "win-x64: Windows did not finish. See $cache/serial.log and C:\\leca\\provision.log" >&2
  exit 1
}

stop_vm() {
  local pid i
  pid="$(vm_pid || true)"
  [[ -n ${pid:-} ]] || return 0
  if ssh_ok; then
    guest "shutdown /s /t 0" >/dev/null 2>&1 || true
  fi
  for ((i = 0; i < 60; i++)); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 2
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" || true
    for ((i = 0; i < 30; i++)); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
    done
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" || true
    fi
  fi
  rm -f "$cache/qemu.pid"
  sleep 1
}

using_installer() {
  local pid
  pid="$(vm_pid || true)"
  [[ -n ${pid:-} ]] || return 1
  tr '\0' ' ' <"/proc/$pid/cmdline" | grep -q windows.iso
}

sync_and_build() {
  say "syncing the project into the guest"
  guest "cmd /c mkdir C:\\leca\\src" >/dev/null 2>&1 || true
  tar -C "$src" -czf - \
    --exclude build \
    --exclude .dart_tool \
    --exclude .git \
    --exclude qemu/.cache \
    --exclude '._*' \
    --exclude .DS_Store \
    . | guest "tar -xzf - -C C:/leca/src"
  # Call flutter.bat by path. A quoted `set PATH=...` is a nested cmd that
  # exits before flutter runs, so Windows reports that flutter is missing.
  say "flutter build windows"
  guest 'rmdir /s /q C:\leca\src\build\windows' || true
  local api="${LECA_AUTH_API:-https://gno.money}"
  guest "cd /d C:\\leca\\src && C:\\flutter\\bin\\flutter.bat build windows --release --dart-define=AUTH_API=${api}"
  mkdir -p "$src/build/windows"
  guest "tar -C C:/leca/src/build/windows -czf - x64" | tar -xzf - -C "$src/build/windows"
  [[ -f $src/build/windows/x64/runner/Release/leca.exe ]] || {
    echo "win-x64: leca.exe was not produced" >&2
    exit 1
  }
  echo "LECA_BUILT windows-x64"
}

reboot_disk() {
  say "$1"
  stop_vm
  boot no
  local i
  for ((i = 0; i < 60; i++)); do
    ssh_ok && return 0
    sleep 5
  done
  echo "win-x64: guest did not come back after reboot" >&2
  exit 1
}

enable_guest_build() {
  guest 'reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock /v AllowDevelopmentWithoutDevLicense /t REG_DWORD /d 1 /f' >/dev/null
  guest 'reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t REG_DWORD /d 1 /f' >/dev/null
  # A fresh image finishes Windows Update and reboots during the compile.
  guest 'reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f' >/dev/null
  guest 'sc config wuauserv start= disabled' >/dev/null || true
  guest 'sc stop wuauserv' >/dev/null || true
  guest 'sc config UsoSvc start= disabled' >/dev/null || true
  guest 'sc stop UsoSvc' >/dev/null || true
  guest 'shutdown /a' >/dev/null || true
  # Defender locks .obj files mid-compile and cl.exe reports permission denied.
  guest 'powershell -NoProfile -Command Add-MpPreference -ExclusionPath C:\leca' >/dev/null || true
  guest 'powershell -NoProfile -Command Add-MpPreference -ExclusionPath C:\flutter' >/dev/null || true
  # $true belongs to PowerShell. Bash must not expand it.
  # shellcheck disable=SC2016
  guest 'powershell -NoProfile -Command Set-MpPreference -DisableRealtimeMonitoring $true' >/dev/null || true
}

ensure_host
wait_iso
write_seed
# An installed disk must never go back through setup. Setup wipes it.
if vm_pid >/dev/null && ! using_installer; then
  : >"$cache/installed"
fi
if ! vm_pid >/dev/null; then
  if [[ -f $cache/installed ]]; then
    say "booting the installed Windows disk"
    boot no
  else
    say "booting the Windows installer"
    boot yes
  fi
fi
if using_installer; then
  wait_ready
  reboot_disk "provision finished, rebooting off the installer"
fi
if ! windows_ready; then
  wait_ready
fi
: >"$cache/installed"
enable_guest_build
if ! vm_mem_matches; then
  reboot_disk "rebooting the guest with ${mem} of RAM"
  wait_ready
fi
sync_and_build
