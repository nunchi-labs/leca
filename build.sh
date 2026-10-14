#!/usr/bin/env bash
# Build each target on the machine that can compile it.
#
#   ./build.sh                         # everything reachable
#   ./build.sh macos android           # just these
#   ./build.sh x86                     # linux-x64 and windows-x64 on the PC
#   ./build.sh linux-arm64 windows-arm64
#
# This Mac:        macos, ios, android, linux-arm64, windows-arm64
# onnig's x86 PC:  linux-x64 (native or WSL) and windows-x64
#
# The PC is scripts/x86.host. The password, if the build key is not
# installed yet, is qemu/.cache/x86/password (not committed).
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
  echo "build: $name on this Mac"
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

usage() {
  cat <<EOF
Usage: ./build.sh [target ...]

  macos  ios  android          this Mac
  linux-arm64  windows-arm64   Ubuntu and Windows 11 ARM VMs on this Mac
  linux-x64  windows-x64       $HOST
  x86                              both x64 targets
  arm                              both arm64 VM targets

No arguments builds every target. x86 is skipped with a message when the PC drops port 22.
EOF
}

expand() {
  case $1 in
    x86) echo linux-x64 windows-x64 ;;
    arm) echo linux-arm64 windows-arm64 ;;
    mac) echo macos ios android ;;
    all) echo macos ios android linux-arm64 windows-arm64 linux-x64 windows-x64 ;;
    *) echo "$1" ;;
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
  local fail=0 t
  for t in "${targets[@]}"; do
    case "$t" in
      macos) build_local macos flutter build macos --release "${AUTH_DEFINE[@]}" || fail=1 ;;
      ios) build_local ios flutter build ios --release --no-codesign "${AUTH_DEFINE[@]}" || fail=1 ;;
      android) build_local android flutter build apk --release "${AUTH_DEFINE[@]}" || fail=1 ;;
      linux-arm64) build_arm linux || fail=1 ;;
      windows-arm64) build_arm windows || fail=1 ;;
      linux-x64 | windows-x64) ;;
      *) die "unknown target $t" ;;
    esac
  done
  local -a x86=()
  for t in "${targets[@]}"; do
    [[ $t == linux-x64 || $t == windows-x64 ]] && x86+=("$t")
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
