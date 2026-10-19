#!/usr/bin/env bash
# Build each target on the machine that can compile it.
#
#   ./build.sh                         # everything these two machines build
#   ./build.sh macos ios               # the Mac
#   ./build.sh android linux-x64 windows-x64
#
#   macos, ios                         the Mac in scripts/mac.host
#   android, linux-x64, windows-x64    the Hetzner machine in scripts/hetzner.host
#   linux-arm64                        Depot CI (depot-ubuntu-24.04-arm-8)
#   windows-arm64                      a Windows ARM machine (Depot has none)
#
# Windows x64 on Hetzner is a KVM guest (scripts/win-x64.sh).
# The Mac key is qemu/.cache/mac/id_ed25519.
set -euo pipefail
export COPYFILE_DISABLE=1

ROOT="$(cd "$(dirname "$0")" && pwd)"
AUTH_DEFINE=(--dart-define="AUTH_API=${LECA_AUTH_API:-https://gno.money}")

die() {
  echo "build: $*" >&2
  exit 1
}

flutter_ref() {
  local ref=""
  if command -v flutter >/dev/null; then
    ref="$(flutter --version 2>/dev/null | awk '/^Flutter / { print $2; exit }')"
  fi
  echo "${ref:-stable}"
}

host_os() {
  case "$(uname -s)" in
    Darwin) echo darwin ;;
    Linux) echo linux ;;
    MINGW* | MSYS* | CYGWIN*) echo windows ;;
    *) echo other ;;
  esac
}

host_arch() {
  # GitHub Actions sets RUNNER_ARCH. An x64 shell on Windows ARM still
  # reports the emulated PROCESSOR_ARCHITECTURE, so check the WOW64 value.
  case "${RUNNER_ARCH:-}" in
    ARM64) echo arm64; return ;;
    X64) echo x64; return ;;
  esac
  local arch="${PROCESSOR_ARCHITEW6432:-${PROCESSOR_ARCHITECTURE:-}}"
  case "$arch" in
    ARM64 | arm64 | aarch64) echo arm64 ;;
    AMD64 | x86_64) echo x64 ;;
    *)
      case "$(uname -m)" in
        x86_64 | amd64) echo x64 ;;
        aarch64 | arm64) echo arm64 ;;
        *) uname -m ;;
      esac
      ;;
  esac
}

# True when `flutter build` for this target can run in this process.
native_ok() {
  local os arch
  os="$(host_os)"
  arch="$(host_arch)"
  case "$1" in
    web) return 0 ;;
    android) [[ $(host_os) == linux ]] ;;
    linux-x64) [[ $os == linux && $arch == x64 ]] ;;
    linux-arm64) [[ $os == linux && $arch == arm64 ]] ;;
    macos | ios) [[ $os == darwin ]] ;;
    windows-x64) [[ $os == windows && $arch == x64 ]] ;;
    windows-arm64) [[ $os == windows && $arch == arm64 ]] ;;
    *) return 1 ;;
  esac
}

build_local() {
  local name=$1
  shift
  echo "build: $name on $(host_os)-$(host_arch)"
  (cd "$ROOT" && "$@")
}

ensure_linux_deps() {
  command -v ninja >/dev/null && pkg-config --exists gtk+-3.0 && command -v zip >/dev/null && return 0
  if [[ $(host_os) != linux ]]; then
    return 0
  fi
  if command -v apt-get >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev unzip zip
  elif command -v pacman >/dev/null; then
    if [[ $(id -u) -eq 0 ]]; then
      pacman -Sy --noconfirm --needed clang cmake ninja pkgconf gtk3 xz zip unzip
    else
      sudo pacman -Sy --noconfirm --needed clang cmake ninja pkgconf gtk3 xz zip unzip
    fi
  fi
}

pack_dir() {
  local dir=$1 zip=$2
  mkdir -p "$(dirname "$zip")"
  rm -f "$zip"
  if command -v zip >/dev/null 2>&1; then
    (cd "$dir" && zip -qry "$zip" .)
  elif command -v cygpath >/dev/null 2>&1 && [[ -n ${SYSTEMROOT:-} ]]; then
    # Git's tar is not bsdtar, and PowerShell rejects a Unix path.
    "$(cygpath -u "$SYSTEMROOT")/System32/tar.exe" -a -cf "$(cygpath -w "$zip")" -C "$(cygpath -w "$dir")" .
  elif tar --version 2>&1 | grep -qi bsdtar; then
    tar -a -cf "$zip" -C "$dir" .
  else
    die "no zip tool for $zip"
  fi
  [[ -s $zip ]]
}

pack_macos() {
  local app
  app="$(echo "$ROOT"/build/macos/Build/Products/Release/*.app)"
  [[ -d $app ]] || return 1
  [[ -x $app/Contents/MacOS/Leca ]] || return 1
  mkdir -p "$ROOT/dist"
  rm -f "$ROOT/dist/Leca-macos.zip"
  if command -v ditto >/dev/null 2>&1; then
    ditto -c -k --keepParent "$app" "$ROOT/dist/Leca-macos.zip"
  else
    (cd "$(dirname "$app")" && zip -qry -y "$ROOT/dist/Leca-macos.zip" "$(basename "$app")")
  fi
  echo "build: Leca-macos.zip"
}

# pffft.c calls _alloca. MSVC declares that in malloc.h. The x64 headers
# include it through the SSE headers; the ARM64 headers do not, so the
# voice library fails with C3861. The package is already in the pub cache.
patch_soloud_alloca() {
  local cache="${PUB_CACHE:-}" file tmp found=0
  if [[ -z $cache && -n ${LOCALAPPDATA:-} ]]; then
    cache="${LOCALAPPDATA}/Pub/Cache"
  fi
  if [[ -z $cache && -n ${HOME:-} ]]; then
    cache="${HOME}/.pub-cache"
  fi
  if command -v cygpath >/dev/null 2>&1; then
    case $cache in
      *\\* | *:*) cache="$(cygpath -u "$cache")" ;;
    esac
  fi
  [[ -d "$cache/hosted" ]] || return 1
  while IFS= read -r -d '' file; do
    found=1
    if grep -q 'include <malloc.h>' "$file"; then
      continue
    fi
    tmp="$(mktemp)"
    awk '
      {
        line = $0
        sub(/\r$/, "", line)
      }
      line == "#elif defined(COMPILER_MSVC)" && !done {
        print line
        print "#  include <malloc.h>"
        done = 1
        next
      }
      { print line }
    ' "$file" >"$tmp"
    mv -f "$tmp" "$file"
    grep -q 'include <malloc.h>' "$file"
    echo "build: included malloc.h in pffft.c"
  done < <(find "$cache/hosted" -type f -path '*/flutter_soloud-*/src/pffft/pffft.c' -print0)
  [[ $found -eq 1 ]]
}

pack_ios() {
  local payload
  [[ -d $ROOT/build/ios/iphoneos/Runner.app ]] || return 1
  payload="$(mktemp -d)"
  mkdir -p "$payload/Payload" "$ROOT/dist"
  cp -R "$ROOT/build/ios/iphoneos/Runner.app" "$payload/Payload/"
  rm -f "$ROOT/dist/Leca-ios-unsigned.ipa"
  (cd "$payload" && zip -qry "$ROOT/dist/Leca-ios-unsigned.ipa" Payload)
  rm -rf "$payload"
  echo "build: Leca-ios-unsigned.ipa"
}

build_native() {
  local target=$1 arch bundle
  case "$target" in
    android)
      build_local android flutter build apk --release "${AUTH_DEFINE[@]}" || return 1
      mkdir -p "$ROOT/dist"
      cp -f "$ROOT/build/app/outputs/flutter-apk/app-release.apk" "$ROOT/dist/Leca-android.apk"
      echo "build: Leca-android.apk"
      ;;
    web)
      build_local web flutter build web --release --base-href /app/ "${AUTH_DEFINE[@]}" || return 1
      pack_dir "$ROOT/build/web" "$ROOT/dist/Leca-web.zip"
      echo "build: Leca-web.zip"
      ;;
    linux-x64 | linux-arm64)
      ensure_linux_deps
      build_local "$target" flutter build linux --release "${AUTH_DEFINE[@]}" || return 1
      arch=x64
      [[ $target == linux-arm64 ]] && arch=arm64
      bundle="$ROOT/build/linux/$arch/release/bundle"
      [[ -x $bundle/leca ]] || return 1
      pack_dir "$bundle" "$ROOT/dist/Leca-linux-$arch.zip"
      echo "build: Leca-linux-$arch.zip"
      ;;
    macos)
      build_local macos flutter build macos --release "${AUTH_DEFINE[@]}" || return 1
      pack_macos || return 1
      ;;
    ios)
      build_local ios flutter build ios --release --no-codesign "${AUTH_DEFINE[@]}" || return 1
      pack_ios || return 1
      ;;
    windows-x64 | windows-arm64)
      arch=x64
      [[ $target == windows-arm64 ]] && arch=arm64
      # VS 2026 removes <experimental/coroutine>. local_auth_windows still
      # includes it. This define keeps that build working.
      export CL="${CL:-} /D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS"
      if [[ $target == windows-arm64 ]]; then
        build_local "$target" flutter pub get
        patch_soloud_alloca || return 1
      fi
      build_local "$target" flutter build windows --release "${AUTH_DEFINE[@]}" || return 1
      bundle="$ROOT/build/windows/$arch/runner/Release"
      [[ -f $bundle/leca.exe ]] || return 1
      pack_dir "$bundle" "$ROOT/dist/Leca-windows-$arch.zip"
      echo "build: Leca-windows-$arch.zip"
      ;;
    *) return 1 ;;
  esac
}

mac_ssh() {
  local host=$1
  shift
  ssh -i "$ROOT/qemu/.cache/mac/id_ed25519" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile="$ROOT/qemu/.cache/mac/known_hosts" \
    -o ConnectTimeout=15 \
    -o IPQoS=none \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=120 \
    "$host" "$@"
}

# Compile on the Mac, then copy dist/ back. The Mac runs this same script.
build_on_mac() {
  local target=$1 host
  [[ -f $ROOT/scripts/mac.host ]] || die "scripts/mac.host is missing"
  [[ -f $ROOT/qemu/.cache/mac/id_ed25519 ]] || die "qemu/.cache/mac/id_ed25519 is missing"
  host="$(tr -d '[:space:]' < "$ROOT/scripts/mac.host")"
  echo "build: $target on $host"
  mac_ssh "$host" "mkdir -p ~/leca" || return 1
  tar -C "$ROOT" --no-xattrs -czf - \
    --exclude build \
    --exclude dist \
    --exclude .dart_tool \
    --exclude .git \
    --exclude qemu/.cache \
    --exclude '._*' \
    --exclude .DS_Store \
    --exclude '**/ephemeral' \
    --exclude '**/.gradle' \
    . | mac_ssh "$host" "tar -xzf - -C ~/leca" || return 1
  mac_ssh "$host" "export PATH=\"/opt/homebrew/bin:\$HOME/flutter/flutter/bin:\$HOME/.cargo/bin:\$PATH\" LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LECA_AUTH_API=$(printf '%q' "${LECA_AUTH_API:-https://gno.money}"); cd ~/leca && ./build.sh $target" || return 1
  mkdir -p "$ROOT/dist"
  mac_ssh "$host" "tar -C ~/leca/dist -czf - ." | tar -xzf - -C "$ROOT/dist" || return 1
}

hetzner_target() {
  [[ -f $ROOT/scripts/hetzner.host ]] || die "scripts/hetzner.host is missing"
  tr -d '[:space:]' < "$ROOT/scripts/hetzner.host"
}

# True on the Hetzner build machine, whose address is scripts/hetzner.host.
on_hetzner() {
  local ip
  ip="$(hetzner_target)"
  ip="${ip#*@}"
  command -v ip >/dev/null || return 1
  ip -4 -o addr show 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | grep -qx "$ip"
}

hetzner_ssh() {
  local host=$1
  shift
  ssh \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=15 \
    -o IPQoS=none \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=120 \
    "$host" "$@"
}

# Windows x64 cannot be compiled on Linux. The guest runs on this machine.
build_windows_local() {
  command -v zip >/dev/null || pacman -S --noconfirm --needed zip
  echo "build: windows-x64 on $(hostname -s) (kvm)"
  LECA_SRC="$ROOT" \
    LECA_FLUTTER_REF="$(flutter_ref)" \
    LECA_AUTH_API="${LECA_AUTH_API:-https://gno.money}" \
    "$ROOT/scripts/win-x64.sh" || return 1
  [[ -f $ROOT/build/windows/x64/runner/Release/leca.exe ]] || return 1
  pack_dir "$ROOT/build/windows/x64/runner/Release" "$ROOT/dist/Leca-windows-x64.zip"
  echo "build: Leca-windows-x64.zip"
}

# Compile on Hetzner, then copy dist/ back. That machine runs this same script.
build_on_hetzner() {
  local target=$1 host
  host="$(hetzner_target)"
  echo "build: $target on $host"
  hetzner_ssh "$host" "mkdir -p ~/leca" || return 1
  tar -C "$ROOT" --no-xattrs -czf - \
    --exclude build \
    --exclude dist \
    --exclude .dart_tool \
    --exclude .git \
    --exclude qemu/.cache \
    --exclude '._*' \
    --exclude .DS_Store \
    --exclude '**/ephemeral' \
    --exclude '**/.gradle' \
    . | hetzner_ssh "$host" "tar -xzf - -C ~/leca" || return 1
  hetzner_ssh "$host" "export PATH=\"/usr/local/bin:/opt/flutter/bin:\$PATH\" LECA_AUTH_API=$(printf '%q' "${LECA_AUTH_API:-https://gno.money}"); cd ~/leca && ./build.sh $target" || return 1
  mkdir -p "$ROOT/dist"
  hetzner_ssh "$host" "tar -C ~/leca/dist -czf - ." | tar -xzf - -C "$ROOT/dist" || return 1
}

usage() {
  cat <<EOF
Usage: ./build.sh [target ...]

  macos  ios                     the Mac (this machine, or scripts/mac.host)
  android  linux-x64  windows-x64   the Hetzner machine (scripts/hetzner.host)
  web                             this machine
  linux-arm64                     Depot CI (an ARM Linux sandbox)
  windows-arm64                   a Windows ARM machine

No arguments builds every target these two machines can produce.
Packages land in dist/.
EOF
}

expand() {
  case $1 in
    x86) echo linux-x64 windows-x64 ;;
    arm) echo linux-arm64 windows-arm64 ;;
    mac) echo macos ios ;;
    all) echo android web linux-x64 macos ios windows-x64 ;;
    *) echo "$1" ;;
  esac
}

# Targets this machine cannot compile.
dispatch_remote() {
  local target=$1
  case "$target" in
    macos | ios) build_on_mac "$target" ;;
    android | linux-x64 | windows-x64) build_on_hetzner "$target" ;;
    linux-arm64)
      echo "build: $target is built on Depot CI (depot-ubuntu-24.04-arm-8)" >&2
      return 1
      ;;
    windows-arm64)
      echo "build: $target needs a Windows ARM machine. Depot CI has no Windows sandbox." >&2
      return 1
      ;;
    *) die "no builder for $target" ;;
  esac
}

main() {
  local -a raw=("$@")
  if [[ ${#raw[@]} -eq 0 ]]; then
    raw=(all)
  fi
  [[ ${raw[0]} == -h || ${raw[0]} == help ]] && { usage; exit 0; }
  local -a targets=()
  local item part
  for item in "${raw[@]}"; do
    for part in $(expand "$item"); do
      targets+=("$part")
    done
  done
  local fail=0 t rc
  for t in "${targets[@]}"; do
    case "$t" in
      android | web | macos | ios | linux-x64 | linux-arm64 | windows-x64 | windows-arm64) ;;
      *) die "unknown target $t" ;;
    esac
    if [[ $t == windows-x64 ]] && on_hetzner; then
      build_windows_local || fail=1
      continue
    fi
    if native_ok "$t"; then
      build_native "$t" || fail=1
      continue
    fi
    set +e
    dispatch_remote "$t"
    rc=$?
    set -e
    [[ $rc -eq 0 ]] || fail=1
  done
  exit "$fail"
}

main "$@"
