#!/usr/bin/env bash
# One Flutter SDK per job.
#
# Depot mounts a shared disk at /mnt/cache. Flutter flock's its artifact
# cache and reads the checkout with git, and that mount breaks both.
# The SDK therefore stays on the runner's own disk there. Pub packages
# still use the shared cache. Elsewhere the SDK stays inside the cache
# directory so GitHub Actions can restore it.
#
# Usage: ensure-flutter.sh <slot> <precache>
#   precache is "host", or a flutter precache flag without the dashes
#   (linux, android, web, macos, ios, windows).
# Jobs must not share a slot.
set -euo pipefail

slot="${1:?slot}"
precache="${2:?precache}"
version="${FLUTTER_VERSION:-3.47.5}"
# shellcheck disable=SC1091
source "$(dirname "$0")/cache-root.sh"

trap 'echo "::error::Flutter setup failed at line $LINENO"' ERR

if [[ -d /mnt/cache ]]; then
  sdk="${RUNNER_TEMP:-/tmp}/flutter-sdk/${slot}"
else
  sdk="$LECA_CACHE/flutter/${slot}/sdk"
fi

ensure_unpack_tools() {
  [[ "$(uname -s)" == Linux ]] || return 0
  if command -v curl >/dev/null 2>&1 \
    && command -v tar >/dev/null 2>&1 \
    && command -v unzip >/dev/null 2>&1 \
    && command -v git >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates curl tar xz-utils unzip git
  else
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends ca-certificates curl tar xz-utils unzip git
  fi
}

# Official stable archives for the pinned version. Other versions, and
# linux arm64 (no archive for this version), are cloned.
archive_url=""
archive_sha=""
if [[ "$version" == 3.47.5 ]]; then
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64 | Linux-amd64)
      archive_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.5-stable.tar.xz"
      archive_sha="2132e990f236f8d22e7c6314b29a191a95b10d7cbcfec9b4e2e303d996652cbb"
      ;;
    Darwin-arm64)
      archive_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.47.5-stable.zip"
      archive_sha="d4dd908b5f8f65515831b6d68ae33307a813f2b68947dded7a1994ee5ea7cead"
      ;;
    Darwin-x86_64)
      archive_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.47.5-stable.zip"
      archive_sha="a7893bb0feecd8bd066f4f7e850356f896a6fc3b862e6c506d21c76691a66b72"
      ;;
    MINGW*-x86_64 | MSYS*-x86_64 | CYGWIN*-x86_64)
      archive_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.5-stable.zip"
      archive_sha="0ccd71931f49c2fbe394b1eeb6d79af3d624058a043ea0d03d34160581624fb8"
      ;;
    *) ;;
  esac
fi

verify_sha() {
  local file=$1 sum=$2
  if command -v sha256sum >/dev/null 2>&1; then
    echo "$sum  $file" | sha256sum -c -
  else
    echo "$sum  $file" | shasum -a 256 -c -
  fi
}

install_sdk() {
  local tmp archive
  ensure_unpack_tools
  rm -rf "$sdk"
  mkdir -p "$(dirname "$sdk")"
  if [[ -n "$archive_url" ]]; then
    tmp="$(mktemp -d)"
    archive="$tmp/flutter.archive"
    echo "Downloading Flutter $version"
    curl -fL --retry 5 --retry-delay 2 -o "$archive" "$archive_url"
    verify_sha "$archive" "$archive_sha"
    case "$archive_url" in
      *.zip) unzip -q "$archive" -d "$tmp" ;;
      *) tar -C "$tmp" -xf "$archive" ;;
    esac
    mv "$tmp/flutter" "$sdk"
    rm -rf "$tmp"
  else
    echo "Cloning Flutter $version"
    git clone --depth 1 --branch "$version" https://github.com/flutter/flutter.git "$sdk"
  fi
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0=safe.directory
  export GIT_CONFIG_VALUE_0="$sdk"
  "$sdk/bin/flutter" config --no-analytics
  if [[ "$precache" == host ]]; then
    "$sdk/bin/flutter" precache
  else
    "$sdk/bin/flutter" precache "--${precache}"
  fi
}

got=""
if [[ -x "$sdk/bin/flutter" ]]; then
  got="$("$sdk/bin/flutter" --version 2>/dev/null | awk '/^Flutter / { print $2; exit }' || true)"
fi
if [[ "$got" != "$version" ]]; then
  install_sdk
fi

export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0="$sdk"
add_github_env GIT_CONFIG_COUNT 1
add_github_env GIT_CONFIG_KEY_0 safe.directory
add_github_env GIT_CONFIG_VALUE_0 "$sdk"
add_github_path "$sdk/bin"
if [[ -z ${PUB_CACHE:-} ]]; then
  mkdir -p "$LECA_CACHE/pub/$slot"
  add_github_env PUB_CACHE "$LECA_CACHE/pub/$slot"
fi
