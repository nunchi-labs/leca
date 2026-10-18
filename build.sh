#!/usr/bin/env bash
# Build each target on the machine that can compile it.
#
#   ./build.sh                         # everything reachable
#   ./build.sh macos android           # just these
#   ./build.sh x86                     # linux-x64 and windows-x64 on the PC
#   ./build.sh linux-arm64 windows-arm64
#
# A target compiles on this machine when the OS matches. Otherwise:
#   macos, ios, linux-arm64, windows-arm64   the Mac in scripts/mac.host
#   linux-arm64, windows-arm64 on that Mac   qemu/build.sh
#   linux-x64, windows-x64                   scripts/x86.host
#
# The PC password, if the build key is not installed yet, is
# qemu/.cache/x86/password (not committed). The Mac key is
# qemu/.cache/mac/id_ed25519.
set -euo pipefail
export COPYFILE_DISABLE=1

ROOT="$(cd "$(dirname "$0")" && pwd)"
AUTH_DEFINE=(--dart-define="AUTH_API=${LECA_AUTH_API:-https://gno.money}")
X86_CACHE="$ROOT/qemu/.cache/x86"
HOST="$(tr -d '[:space:]' < "$ROOT/scripts/x86.host")"
KEY="$X86_CACHE/id_ed25519"

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
    web | android) return 0 ;;
    linux-x64) [[ $os == linux && $arch == x64 ]] ;;
    linux-arm64) [[ $os == linux && $arch == arm64 ]] ;;
    macos | ios) [[ $os == darwin ]] ;;
    windows-x64) [[ $os == windows && $arch == x64 ]] ;;
    windows-arm64) [[ $os == windows && $arch == arm64 ]] ;;
    *) return 1 ;;
  esac
}

ensure_key() {
  mkdir -p "$X86_CACHE"
  if [[ ! -f $KEY ]]; then
    ssh-keygen -t ed25519 -N "" -f "$KEY" -C leca-build >/dev/null
  fi
}

# One TCP session for the whole build. A burst of new connections makes
# this PC stop listening on port 22.
x86_opts() {
  X86_OPTS=(
    -i "$KEY"
    -o BatchMode=yes
    -o StrictHostKeyChecking=accept-new
    -o UserKnownHostsFile="$X86_CACHE/known_hosts"
    -o ConnectTimeout=12
    -o LogLevel=ERROR
    -o ControlMaster=auto
    -o ControlPath="$X86_CACHE/cm.sock"
    -o ControlPersist=30m
    -o ServerAliveInterval=30
    -o ServerAliveCountMax=120
  )
}

x86_open() {
  ensure_key
  mkdir -p "$X86_CACHE"
  x86_opts
  if ssh "${X86_OPTS[@]}" -O check "$HOST" >/dev/null 2>&1; then
    return 0
  fi
  rm -f "$X86_CACHE/cm.sock"
  if ssh "${X86_OPTS[@]}" -f -N "$HOST"; then
    return 0
  fi
  local passfile="$X86_CACHE/password"
  [[ -f $passfile ]] || return 1
  local ask
  ask="$(mktemp)"
  cat >"$ask" <<EOF
#!/bin/sh
cat "$passfile"
EOF
  chmod 700 "$ask"
  DISPLAY="${DISPLAY:-:0}" SSH_ASKPASS="$ask" SSH_ASKPASS_REQUIRE=force \
    ssh "${X86_OPTS[@]}" \
      -o PreferredAuthentications=password \
      -o PubkeyAuthentication=no \
      -f -N "$HOST"
  local rc=$?
  rm -f "$ask"
  return "$rc"
}

x86_reachable() {
  x86_open
}

unreachable() {
  cat >&2 <<EOF
build: cannot log in to ${HOST}.
The build key is qemu/.cache/x86/id_ed25519. On that machine, sshd must
accept it for the user in scripts/x86.host.
EOF
  exit 1
}

# Run a command on the x86 PC over the shared connection.
x86_ssh() {
  x86_open || unreachable
  x86_opts
  ssh "${X86_OPTS[@]}" "$HOST" "$@"
}

x86_kind() {
  # linux, or windows. echo ok works in both bash and cmd.
  local out
  out="$(x86_ssh 'bash -lc "echo linux" || echo windows')"
  if [[ $out == *linux* ]]; then
    echo linux
  else
    echo windows
  fi
}

sync_tree() {
  local dest_tar=$1
  tar -C "$ROOT" --no-xattrs -czf - \
    --exclude build \
    --exclude .dart_tool \
    --exclude .git \
    --exclude qemu/.cache \
    --exclude '._*' \
    --exclude .DS_Store \
    --exclude '**/ephemeral' \
    --exclude '**/.gradle' \
    . | x86_ssh "$dest_tar"
}

build_local() {
  local name=$1
  shift
  echo "build: $name on $(host_os)-$(host_arch)"
  (cd "$ROOT" && "$@")
}

build_arm() {
  local which=$1
  echo "build: $which on this Mac (qemu)"
  "$ROOT/qemu/build.sh" "$which"
}

build_x86() {
  local -a want=("$@")
  echo "build: ${want[*]} on $HOST"
  local kind ref
  kind="$(x86_kind)"
  ref="$(flutter_ref)"
  echo "build: $HOST is $kind, flutter $ref"
  if [[ $kind == linux ]]; then
    x86_ssh "mkdir -p ~/leca" || return 1
    sync_tree "tar -xzf - -C ~/leca" || return 1
    local sudo_pass=""
    [[ -f $X86_CACHE/password ]] && sudo_pass="$(tr -d '[:space:]' < "$X86_CACHE/password")"
    [[ -n $sudo_pass ]] || die "qemu/.cache/x86/password is empty"
    local envp="LECA_SUDO_PASSWORD=$(printf '%q' "$sudo_pass") LECA_FLUTTER_REF=$(printf '%q' "$ref")"
    local t want_linux=no want_win=no
    for t in "${want[@]}"; do
      [[ $t == linux-x64 ]] && want_linux=yes
      [[ $t == windows-x64 ]] && want_win=yes
    done
    if [[ $want_linux == yes ]]; then
      x86_ssh "$envp bash ~/leca/scripts/remote.sh" || return 1
      mkdir -p "$ROOT/build/linux"
      x86_ssh "tar -C ~/leca/build/linux -czf - x64" | tar -xzf - -C "$ROOT/build/linux" || return 1
      [[ -e $ROOT/build/linux/x64/release/bundle ]] || return 1
      echo "build: linux-x64 bundle is in build/linux/x64/"
    fi
    if [[ $want_win == yes ]]; then
      x86_ssh "$envp bash ~/leca/scripts/win-x64.sh" || return 1
      mkdir -p "$ROOT/build/windows"
      x86_ssh "tar -C ~/leca/build/windows -czf - x64" | tar -xzf - -C "$ROOT/build/windows" || return 1
      [[ -f $ROOT/build/windows/x64/runner/Release/leca.exe ]] || return 1
      echo "build: windows-x64 bundle is in build/windows/x64/"
    fi
    return 0
  fi
  x86_ssh 'powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path C:\leca\src | Out-Null"'
  sync_tree "tar -xzf - -C C:/leca/src"
  local args=""
  local t
  for t in "${want[@]}"; do
    args+=" $t"
  done
  x86_ssh "powershell -NoProfile -ExecutionPolicy Bypass -File C:\\leca\\src\\scripts\\remote.ps1 -Ref $ref $args"
  for t in "${want[@]}"; do
    if [[ $t == windows-x64 ]]; then
      mkdir -p "$ROOT/build/windows"
      x86_ssh "tar -C C:/leca/src/build/windows -czf - x64" | tar -xzf - -C "$ROOT/build/windows"
      echo "build: windows-x64 bundle is in build/windows/x64/"
    else
      mkdir -p "$ROOT/build/linux"
      x86_ssh "tar -C C:/leca/src/build/linux -czf - x64" | tar -xzf - -C "$ROOT/build/linux"
      echo "build: linux-x64 bundle is in build/linux/x64/"
    fi
  done
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
  mkdir -p "$ROOT/dist"
  rm -f "$ROOT/dist/Leca-macos.zip"
  if command -v ditto >/dev/null 2>&1; then
    ditto -c -k --keepParent "$app" "$ROOT/dist/Leca-macos.zip"
  else
    (cd "$(dirname "$app")" && zip -qry -y "$ROOT/dist/Leca-macos.zip" "$(basename "$app")")
  fi
  echo "build: Leca-macos.zip"
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
      build_local android flutter build apk --release "${AUTH_DEFINE[@]}"
      mkdir -p "$ROOT/dist"
      cp -f "$ROOT/build/app/outputs/flutter-apk/app-release.apk" "$ROOT/dist/Leca-android.apk"
      echo "build: Leca-android.apk"
      ;;
    web)
      build_local web flutter build web --release --base-href /app/ "${AUTH_DEFINE[@]}"
      pack_dir "$ROOT/build/web" "$ROOT/dist/Leca-web.zip"
      echo "build: Leca-web.zip"
      ;;
    linux-x64 | linux-arm64)
      ensure_linux_deps
      build_local "$target" flutter build linux --release "${AUTH_DEFINE[@]}"
      arch=x64
      [[ $target == linux-arm64 ]] && arch=arm64
      bundle="$ROOT/build/linux/$arch/release/bundle"
      [[ -x $bundle/leca ]] || return 1
      pack_dir "$bundle" "$ROOT/dist/Leca-linux-$arch.zip"
      echo "build: Leca-linux-$arch.zip"
      ;;
    macos)
      build_local macos flutter build macos --release "${AUTH_DEFINE[@]}"
      pack_macos
      ;;
    ios)
      build_local ios flutter build ios --release --no-codesign "${AUTH_DEFINE[@]}"
      pack_ios
      ;;
    windows-x64 | windows-arm64)
      arch=x64
      [[ $target == windows-arm64 ]] && arch=arm64
      # VS 2026 removes <experimental/coroutine>. local_auth_windows still
      # includes it. This define keeps that build working.
      export CL="${CL:-} /D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS"
      build_local "$target" flutter build windows --release "${AUTH_DEFINE[@]}"
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

usage() {
  cat <<EOF
Usage: ./build.sh [target ...]

  macos  ios                  a Mac (this machine, or scripts/mac.host)
  android  web                this machine
  linux-x64  linux-arm64      this machine when the arch matches, else the Mac VM or $HOST
  windows-x64  windows-arm64  this machine when the arch matches, else the Mac VM or $HOST
  x86                              both x64 targets
  arm                              both arm64 VM targets

No arguments builds every target. Packages land in dist/.
EOF
}

expand() {
  case $1 in
    x86) echo linux-x64 windows-x64 ;;
    arm) echo linux-arm64 windows-arm64 ;;
    mac) echo macos ios android ;;
    all) echo android web linux-x64 linux-arm64 macos ios windows-x64 windows-arm64 ;;
    *) echo "$1" ;;
  esac
}

# Targets this machine cannot compile. Arm VMs run on the Mac.
dispatch_remote() {
  local target=$1
  case "$target" in
    macos | ios) build_on_mac "$target" ;;
    linux-arm64 | windows-arm64)
      if [[ $(host_os) == darwin ]]; then
        if [[ $target == linux-arm64 ]]; then
          build_arm linux
        else
          build_arm windows
        fi
      else
        build_on_mac "$target"
      fi
      ;;
    linux-x64 | windows-x64) return 2 ;;
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
  local -a x86=()
  for t in "${targets[@]}"; do
    case "$t" in
      android | web | macos | ios | linux-x64 | linux-arm64 | windows-x64 | windows-arm64) ;;
      *) die "unknown target $t" ;;
    esac
    if native_ok "$t"; then
      build_native "$t" || fail=1
      continue
    fi
    set +e
    dispatch_remote "$t"
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
      continue
    elif [[ $rc -eq 2 ]]; then
      x86+=("$t")
    else
      fail=1
    fi
  done
  if [[ ${#x86[@]} -gt 0 ]]; then
    if x86_reachable; then
      build_x86 "${x86[@]}" || fail=1
    else
      unreachable || fail=1
    fi
  fi
  exit "$fail"
}

main "$@"
