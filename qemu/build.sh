#!/usr/bin/env bash
# Persistent QEMU build VMs for this Mac (Apple Silicon, HVF).
#
#   ./qemu/build.sh linux
#   ./qemu/build.sh windows
#   ./qemu/build.sh stop [linux|windows]
#
# Disks, ISOs, and keys stay in qemu/.cache. The next build only syncs
# the tree and compiles. Delete qemu/.cache/<os> to start that VM over.
#
# CHOW_QEMU_MEM   default 8G
# CHOW_QEMU_CPUS  default 4
set -euo pipefail
# macOS tar otherwise stuffs AppleDouble ._* files into the archive, and
# Flutter then tries to parse them as source.
export COPYFILE_DISABLE=1

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$ROOT/qemu/.cache"
MEM="${CHOW_QEMU_MEM:-8G}"
CPUS="${CHOW_QEMU_CPUS:-4}"
LINUX_PORT=2222
WIN_PORT=2223

usage() {
  cat <<EOF
Usage: ./qemu/build.sh linux|windows|stop [linux|windows]

  linux     flutter build linux inside an Ubuntu VM
  windows   flutter build windows inside a Windows 11 ARM VM
  stop      power the VM off

Images live in qemu/.cache and are reused. CHOW_QEMU_MEM=$MEM CHOW_QEMU_CPUS=$CPUS
EOF
}

die() {
  echo "qemu: $*" >&2
  exit 1
}

need_tools() {
  local missing=()
  command -v brew >/dev/null || die "Homebrew is required to install qemu"
  command -v qemu-system-aarch64 >/dev/null || missing+=(qemu)
  command -v qemu-img >/dev/null || missing+=(qemu)
  command -v mkisofs >/dev/null || missing+=(cdrtools)
  if [[ ${#missing[@]} -gt 0 ]]; then
    brew install qemu cdrtools
  fi
  command -v qemu-system-aarch64 >/dev/null || die "qemu-system-aarch64 is not on PATH"
  command -v mkisofs >/dev/null || die "mkisofs is not on PATH"
}

firmware() {
  local name=$1
  local root file
  for root in /opt/homebrew/share/qemu /usr/local/share/qemu; do
    file="$root/$name"
    if [[ -f $file ]]; then
      echo "$file"
      return
    fi
  done
  die "missing $name (brew install qemu)"
}

flutter_ref() {
  local ref=""
  if command -v flutter >/dev/null; then
    ref="$(flutter --version 2>/dev/null | awk '/^Flutter / { print $2; exit }')"
  fi
  if [[ -z $ref ]]; then
    ref="3.47.5"
  fi
  echo "$ref"
}

ensure_key() {
  local dir=$1
  mkdir -p "$dir"
  if [[ ! -f $dir/id_ed25519 ]]; then
    ssh-keygen -t ed25519 -N "" -f "$dir/id_ed25519" -C chow-qemu >/dev/null
  fi
}

ssh_base() {
  local port=$1 key=$2
  echo "ssh -i $key -p $port -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR"
}

ssh_ok() {
  local port=$1 key=$2 user=$3
  # shellcheck disable=SC2046
  # echo works in both bash and Windows cmd. `true` does not exist on cmd.
  $(ssh_base "$port" "$key") "$user@127.0.0.1" echo ok >/dev/null 2>&1
}

vm_running() {
  local pidfile=$1
  [[ -f $pidfile ]] || return 1
  local pid
  pid="$(cat "$pidfile")"
  [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null
}

download() {
  local url=$1 dest=$2
  if [[ -f $dest ]]; then
    return
  fi
  echo "qemu: downloading $(basename "$dest")"
  curl -fL --retry 3 --retry-delay 2 -o "$dest.partial" "$url"
  mv "$dest.partial" "$dest"
}

launch() {
  local pidfile=$1
  shift
  if vm_running "$pidfile"; then
    return
  fi
  rm -f "$pidfile"
  qemu-system-aarch64 "$@"
  sleep 1
  vm_running "$pidfile" || die "qemu did not stay up. See $(dirname "$pidfile")/serial.log"
}

wait_ssh() {
  local port=$1 key=$2 user=$3 seconds=$4
  local i
  echo "qemu: waiting for ssh on port $port"
  for ((i = 0; i < seconds; i += 5)); do
    if ssh_ok "$port" "$key" "$user"; then
      return
    fi
    sleep 5
  done
  die "ssh on port $port did not come up"
}

guest() {
  local port=$1 key=$2 user=$3
  shift 3
  # shellcheck disable=SC2046
  $(ssh_base "$port" "$key") "$user@127.0.0.1" "$@"
}

ensure_linux_flutter() {
  local key=$1 ref=$2
  echo "qemu: waiting for cloud-init"
  guest "$LINUX_PORT" "$key" chow sudo cloud-init status --wait || true
  if guest "$LINUX_PORT" "$key" chow test -x /home/chow/flutter/bin/flutter; then
    guest "$LINUX_PORT" "$key" chow mkdir -p /home/chow/src
    return
  fi
  echo "qemu: installing flutter ${ref}"
  local script
  script="$(mktemp)"
  cat >"$script" <<EOF
#!/bin/bash
set -euo pipefail
if [[ ! -x /home/chow/flutter/bin/flutter ]]; then
  git clone --depth 1 --branch ${ref} https://github.com/flutter/flutter.git /home/chow/flutter || git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /home/chow/flutter
fi
/home/chow/flutter/bin/flutter config --no-analytics --enable-linux-desktop
/home/chow/flutter/bin/flutter precache --linux
mkdir -p /home/chow/src
EOF
  guest "$LINUX_PORT" "$key" chow sudo chown chow:chow /home/chow
  scp -i "$key" -P "$LINUX_PORT" \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    "$script" chow@127.0.0.1:provision.sh
  rm -f "$script"
  guest "$LINUX_PORT" "$key" chow bash /home/chow/provision.sh \
    || die "flutter install in the linux vm failed"
}

sync_linux() {
  local key=$1
  local rsh
  rsh="$(ssh_base "$LINUX_PORT" "$key")"
  echo "qemu: syncing project into the linux vm"
  rsync -az --delete \
    --exclude build/ \
    --exclude .dart_tool/ \
    --exclude .git/ \
    --exclude qemu/.cache/ \
    --exclude '._*' \
    --exclude .DS_Store \
    --exclude '**/ephemeral/' \
    --exclude '**/.gradle/' \
    -e "$rsh" \
    "$ROOT/" "chow@127.0.0.1:src/"
}

write_linux_seed() {
  local dir=$1 ref=$2
  local pub seed
  pub="$(cat "$dir/id_ed25519.pub")"
  seed="$dir/seed"
  mkdir -p "$seed"
  cat >"$seed/meta-data" <<EOF
instance-id: chow-linux
local-hostname: chow-linux
EOF
  cat >"$seed/network-config" <<'EOF'
version: 2
ethernets:
  nic0:
    match:
      driver: virtio*
    dhcp4: true
EOF
  cat >"$seed/user-data" <<EOF
#cloud-config
hostname: chow-linux
users:
  - name: chow
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    plain_text_passwd: chow
    ssh_authorized_keys:
      - ${pub}
ssh_pwauth: false
package_update: true
packages:
  - openssh-server
  - curl
  - git
  - unzip
  - xz-utils
  - zip
  - ca-certificates
  - build-essential
  - clang
  - cmake
  - ninja-build
  - pkg-config
  - libgtk-3-dev
  - liblzma-dev
  - rsync
write_files:
  - path: /home/chow/provision.sh
    defer: true
    owner: chow:chow
    permissions: "0755"
    content: |
      #!/bin/bash
      set -euo pipefail
      if [[ ! -x /home/chow/flutter/bin/flutter ]]; then
        git clone --depth 1 --branch ${ref} https://github.com/flutter/flutter.git /home/chow/flutter || git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /home/chow/flutter
      fi
      /home/chow/flutter/bin/flutter config --no-analytics --enable-linux-desktop
      /home/chow/flutter/bin/flutter precache --linux
      mkdir -p /home/chow/src
runcmd:
  - chown chow:chow /home/chow
  - su - chow -c /home/chow/provision.sh
EOF
  (
    cd "$seed"
    mkisofs -output "$dir/seed.iso" -volid cidata -joliet -rock \
      -quiet user-data meta-data network-config
  )
}

boot_linux() {
  local dir=$1
  local code vars
  code="$(firmware edk2-aarch64-code.fd)"
  vars="$(firmware edk2-arm-vars.fd)"
  if [[ ! -f $dir/efi-vars.fd ]]; then
    cp "$vars" "$dir/efi-vars.fd"
  fi
  launch "$dir/qemu.pid" \
    -name chow-linux \
    -machine virt,accel=hvf,highmem=on \
    -cpu host \
    -smp "$CPUS" \
    -m "$MEM" \
    -drive if=pflash,format=raw,readonly=on,file="$code" \
    -drive if=pflash,format=raw,file="$dir/efi-vars.fd" \
    -drive if=virtio,format=qcow2,file="$dir/disk.qcow2" \
    -drive if=virtio,format=raw,media=cdrom,file="$dir/seed.iso",readonly=on \
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:${LINUX_PORT}-:22 \
    -device virtio-net-pci,netdev=net0 \
    -display none \
    -serial file:"$dir/serial.log" \
    -pidfile "$dir/qemu.pid" \
    -daemonize
}

build_linux() {
  local dir="$CACHE/linux"
  local ref
  ref="$(flutter_ref)"
  mkdir -p "$dir"
  ensure_key "$dir"
  download \
    "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img" \
    "$dir/base.img"
  if [[ ! -f $dir/disk.qcow2 ]]; then
    qemu-img create -f qcow2 -b "$dir/base.img" -F qcow2 "$dir/disk.qcow2" 40G >/dev/null
    write_linux_seed "$dir" "$ref"
  elif [[ ! -f $dir/seed.iso ]]; then
    write_linux_seed "$dir" "$ref"
  fi
  boot_linux "$dir"
  wait_ssh "$LINUX_PORT" "$dir/id_ed25519" chow 600
  ensure_linux_flutter "$dir/id_ed25519" "$ref"
  sync_linux "$dir/id_ed25519"
  echo "qemu: flutter build linux"
  guest "$LINUX_PORT" "$dir/id_ed25519" chow \
    "bash -lc 'export PATH=\$HOME/flutter/bin:\$PATH; cd \$HOME/src && flutter build linux --release --dart-define=AUTH_API=https://gno.money'"
  mkdir -p "$ROOT/build"
  rsync -az \
    -e "$(ssh_base "$LINUX_PORT" "$dir/id_ed25519")" \
    "chow@127.0.0.1:src/build/linux/" "$ROOT/build/linux/"
  echo "qemu: linux bundle is in build/linux/"
}

# This firmware will not start the Windows ISO from a USB CD (it shows up as a
# hard disk with no boot file and drops to the UEFI shell). A FAT disk with the
# DVD bootloader and boot.wim does start. install.wim stays on the ISO.
refresh_windows_bootdisk() {
  local dir=$1 mnt
  mnt="$(hdiutil attach -nobrowse "$dir/boot.img" 2>/dev/null | awk 'END { print $NF }')" || return 0
  [[ -d ${mnt:-} ]] || return 0
  cp "$dir/seed/autounattend.xml" "$dir/seed/provision.ps1" \
    "$dir/seed/id_ed25519.pub" "$dir/seed/flutter.ref" "$mnt/"
  printf '%s\n' '@echo off' 'powershell.exe -ExecutionPolicy Bypass -File %~dp0provision.ps1' >"$mnt/go.cmd"
  sync
  hdiutil detach "$mnt" >/dev/null || true
}

prepare_windows_bootdisk() {
  local dir=$1
  local img="$dir/boot.img"
  if [[ -f $img ]]; then
    refresh_windows_bootdisk "$dir" || true
    return
  fi
  echo "qemu: building FAT boot disk for Windows setup"
  local iso_mnt mnt dmg
  iso_mnt="$(hdiutil attach -readonly -nobrowse "$dir/windows.iso" | awk 'END { print $NF }')"
  [[ -f $iso_mnt/sources/boot.wim ]] || die "windows iso did not mount ($iso_mnt)"
  dmg="$dir/boot.dmg"
  rm -f "$dmg"
  hdiutil create -size 1024m -fs FAT32 -volname CHOWBOOT -layout MBRSPUD -ov "$dmg" >/dev/null
  mnt="$(hdiutil attach -nobrowse "$dmg" | awk 'END { print $NF }')"
  [[ -d $mnt ]] || die "FAT boot disk did not mount ($mnt)"
  mkdir -p "$mnt/EFI/BOOT" "$mnt/sources"
  cp "$iso_mnt/efi/boot/bootaa64.efi" "$mnt/EFI/BOOT/BOOTAA64.EFI"
  cp -R "$iso_mnt/efi/microsoft" "$mnt/EFI/Microsoft"
  cp -R "$iso_mnt/boot" "$mnt/boot"
  cp "$iso_mnt/bootmgr.efi" "$mnt/bootmgr.efi"
  cp "$iso_mnt/sources/boot.wim" "$mnt/sources/boot.wim"
  cp "$dir/seed/autounattend.xml" "$dir/seed/provision.ps1" \
    "$dir/seed/id_ed25519.pub" "$dir/seed/flutter.ref" "$mnt/"
  printf '%s\n' '@echo off' 'powershell.exe -ExecutionPolicy Bypass -File %~dp0provision.ps1' >"$mnt/go.cmd"
  sync
  hdiutil detach "$mnt" >/dev/null
  hdiutil detach "$iso_mnt" >/dev/null || true
  mv "$dmg" "$img"
}

write_windows_seed() {
  local dir=$1 ref=$2
  local seed="$dir/seed"
  mkdir -p "$seed"
  cp "$ROOT/qemu/windows/autounattend.xml" "$seed/autounattend.xml"
  cp "$ROOT/qemu/windows/provision.ps1" "$seed/provision.ps1"
  cp "$dir/id_ed25519.pub" "$seed/id_ed25519.pub"
  echo "$ref" >"$seed/flutter.ref"
  (
    cd "$seed"
    mkisofs -output "$dir/seed.iso" -volid CHOWSEED -joliet -rock -quiet \
      autounattend.xml provision.ps1 id_ed25519.pub flutter.ref
  )
}

boot_windows() {
  local dir=$1 with_iso=$2
  local code vars
  code="$(firmware edk2-aarch64-code.fd)"
  vars="$(firmware edk2-arm-vars.fd)"
  if [[ ! -f $dir/efi-vars.fd ]]; then
    cp "$vars" "$dir/efi-vars.fd"
  fi
  local -a args=(
    -name chow-windows
    -machine virt,accel=hvf,highmem=on
    -cpu host
    -smp "$CPUS"
    -m "$MEM"
    -drive if=pflash,format=raw,readonly=on,file="$code"
    -drive if=pflash,format=raw,file="$dir/efi-vars.fd"
    -device ramfb
    -display none
    -device qemu-xhci,id=xhci
    -device usb-kbd
    -device usb-tablet
    -device nvme,drive=system,serial=chowdisk,bootindex=0
    -drive if=none,id=system,format=qcow2,file="$dir/disk.qcow2"
    -device usb-storage,drive=seed
    -drive if=none,id=seed,format=raw,media=cdrom,file="$dir/seed.iso",readonly=on
    -device usb-storage,drive=virtio
    -drive if=none,id=virtio,format=raw,media=cdrom,file="$dir/virtio-win.iso",readonly=on
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:${WIN_PORT}-:22
    -device virtio-net-pci,netdev=net0
    -device virtio-rng-pci
    -serial file:"$dir/serial.log"
    -pidfile "$dir/qemu.pid"
    -daemonize
  )
  if [[ $with_iso == yes ]]; then
    args+=(
      -device virtio-blk-pci,drive=esp,bootindex=1
      -drive if=none,id=esp,format=raw,file="$dir/boot.img"
      -device usb-storage,drive=install
      -drive if=none,id=install,format=raw,media=cdrom,file="$dir/windows.iso",readonly=on
    )
  fi
  launch "$dir/qemu.pid" "${args[@]}"
}

windows_ready() {
  local key=$1
  guest "$WIN_PORT" "$key" chow "cmd /c if exist C:\\chow\\ready exit 0 else exit 1"
}

build_windows() {
  local dir="$CACHE/windows"
  local ref
  ref="$(flutter_ref)"
  mkdir -p "$dir"
  ensure_key "$dir"
  download \
    "https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENT_CONSUMER_a64fre_en-us.iso" \
    "$dir/windows.iso"
  download \
    "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso" \
    "$dir/virtio-win.iso"
  if [[ ! -f $dir/disk.qcow2 ]]; then
    qemu-img create -f qcow2 "$dir/disk.qcow2" 80G >/dev/null
  fi
  write_windows_seed "$dir" "$ref"
  prepare_windows_bootdisk "$dir"
  local installed=no
  if vm_running "$dir/qemu.pid" && ssh_ok "$WIN_PORT" "$dir/id_ed25519" chow; then
    if windows_ready "$dir/id_ed25519"; then
      installed=yes
    fi
  fi
  if [[ $installed == no ]]; then
    boot_windows "$dir" yes
    echo "qemu: installing Windows (headless). First boot installs the OS, OpenSSH, Visual Studio, and Flutter"
    local i
    for ((i = 0; i < 240; i++)); do
      if ssh_ok "$WIN_PORT" "$dir/id_ed25519" chow && windows_ready "$dir/id_ed25519"; then
        installed=yes
        break
      fi
      if ((i % 6 == 0)); then
        echo "qemu: still waiting for Windows provision ($((i / 2)) min)"
      fi
      sleep 30
    done
    [[ $installed == yes ]] || die "Windows did not finish provisioning. See $dir and the guest log C:\\chow\\provision.log"
    # Reboot onto the installed disk without the setup ISO.
    guest "$WIN_PORT" "$dir/id_ed25519" chow "shutdown /s /t 0" || true
    local pid
    pid="$(cat "$dir/qemu.pid")"
    for ((i = 0; i < 60; i++)); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 2
    done
    kill -0 "$pid" 2>/dev/null && kill "$pid" || true
    sleep 2
  fi
  boot_windows "$dir" no
  wait_ssh "$WIN_PORT" "$dir/id_ed25519" chow 180
  echo "qemu: syncing project into the windows vm"
  guest "$WIN_PORT" "$dir/id_ed25519" chow "cmd /c mkdir C:\\chow\\src" || true
  tar -C "$ROOT" -czf - \
    --exclude build \
    --exclude .dart_tool \
    --exclude .git \
    --exclude qemu/.cache \
    --exclude '._*' \
    --exclude .DS_Store \
    . | guest "$WIN_PORT" "$dir/id_ed25519" chow "tar -xzf - -C C:/chow/src"
  echo "qemu: flutter build windows"
  guest "$WIN_PORT" "$dir/id_ed25519" chow \
    'cmd /c "set PATH=C:\flutter\bin;%PATH%&& cd /d C:\chow\src&& flutter build windows --release --dart-define=AUTH_API=https://gno.money"'
  mkdir -p "$ROOT/build"
  guest "$WIN_PORT" "$dir/id_ed25519" chow "tar -C C:/chow/src/build -czf - windows" \
    | tar -xzf - -C "$ROOT/build"
  echo "qemu: windows bundle is in build/windows/"
}

stop_one() {
  local name=$1 port=$2 user=$3
  local dir="$CACHE/$name"
  local key="$dir/id_ed25519"
  if [[ ! -f $dir/qemu.pid ]]; then
    echo "qemu: $name is not running"
    return
  fi
  if ssh_ok "$port" "$key" "$user"; then
    if [[ $name == linux ]]; then
      guest "$port" "$key" "$user" sudo poweroff || true
    else
      guest "$port" "$key" "$user" "shutdown /s /t 0" || true
    fi
  fi
  local pid i
  pid="$(cat "$dir/qemu.pid" 2>/dev/null || true)"
  if [[ -n ${pid:-} ]]; then
    for ((i = 0; i < 30; i++)); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
    done
    kill -0 "$pid" 2>/dev/null && kill "$pid" || true
  fi
  rm -f "$dir/qemu.pid"
  echo "qemu: stopped $name"
}

main() {
  local cmd=${1:-}
  need_tools
  case "$cmd" in
    linux) build_linux ;;
    windows) build_windows ;;
    stop)
      case ${2:-all} in
        linux) stop_one linux "$LINUX_PORT" chow ;;
        windows) stop_one windows "$WIN_PORT" chow ;;
        all)
          stop_one linux "$LINUX_PORT" chow
          stop_one windows "$WIN_PORT" chow
          ;;
        *) die "stop linux|windows" ;;
      esac
      ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
