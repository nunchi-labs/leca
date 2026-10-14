#!/bin/bash
# Runs on the x86 machine after the tree is synced.
# On Omarchy: system packages via `omarchy pkg add`, Flutter via mise.
# On Debian or WSL: apt, then a Flutter git checkout.
set -euo pipefail

ref="${LECA_FLUTTER_REF:-stable}"
here="$(cd "$(dirname "$0")" && pwd)"
src="$(cd "$here/.." && pwd)"

# A tree on /mnt/c is a Windows drive. Flutter needs a Linux filesystem.
case "$src" in
  /mnt/*)
    publish="${LECA_PUBLISH:-$src/build/linux}"
    dest="$HOME/leca"
    mkdir -p "$dest"
    tar -C "$src" -cf - \
      --exclude build --exclude .dart_tool --exclude .git --exclude qemu/.cache \
      . | tar -C "$dest" -xf -
    src="$dest"
    ;;
esac

as_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    "$@"
    return
  fi
  if [[ -z ${LECA_SUDO_PASSWORD:-} ]]; then
    sudo -n "$@"
    return
  fi
  # One sudo. A cached timestamp does not carry into Omarchy's own sudo.
  echo "$LECA_SUDO_PASSWORD" | sudo -S -p '' "$@"
}

install_omarchy() {
  # omarchy-pkg-add is `omarchy pkg add`. As root it runs pacman --needed.
  as_root omarchy-pkg-add clang cmake ninja pkgconf gtk3 xz gcc glu unzip curl git zip
  export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
  command -v mise >/dev/null || { echo "build: mise is not installed" >&2; exit 1; }
  mise use -g "flutter@${ref}" || mise use -g flutter@latest
  eval "$(mise activate bash)"
}

install_debian() {
  if ! command -v ninja >/dev/null || ! command -v clang >/dev/null || ! pkg-config --exists gtk+-3.0; then
    as_root apt-get update
    as_root apt-get install -y build-essential clang cmake ninja-build pkg-config \
      libgtk-3-dev liblzma-dev unzip curl git xz-utils zip
  fi
  if [[ ! -x "$HOME/flutter/bin/flutter" ]]; then
    git clone --depth 1 --branch "$ref" https://github.com/flutter/flutter.git "$HOME/flutter" \
      || git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$HOME/flutter"
  fi
  export PATH="$HOME/flutter/bin:$PATH"
}

if [[ -r /etc/os-release ]] && grep -q '^ID=omarchy' /etc/os-release; then
  install_omarchy
else
  install_debian
fi

flutter config --no-analytics --enable-linux-desktop >/dev/null
cd "$src"
flutter build linux --release --dart-define="AUTH_API=${LECA_AUTH_API:-https://gno.money}"
if [[ -n ${publish:-} ]]; then
  mkdir -p "$publish"
  rm -rf "$publish/x64"
  tar -C "$src/build/linux" -cf - x64 | tar -C "$publish" -xf -
fi
echo "LECA_BUILT linux-x64"
