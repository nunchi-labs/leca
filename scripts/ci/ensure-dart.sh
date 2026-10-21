#!/usr/bin/env bash
# Dart SDK for one CI job.
#
# Usage: ensure-dart.sh <slot>
# A slot is one job. Parallel jobs do not share a directory.
set -euo pipefail

slot="${1:?slot}"
version="${DART_VERSION:-3.13.4}"
# shellcheck disable=SC1091
source "$(dirname "$0")/cache-root.sh"
root="$LECA_CACHE/dart/${slot}/${version}"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64 | Linux-amd64) dart_os=linux dart_arch=x64 ;;
  Linux-aarch64 | Linux-arm64) dart_os=linux dart_arch=arm64 ;;
  Darwin-arm64) dart_os=macos dart_arch=arm64 ;;
  Darwin-x86_64) dart_os=macos dart_arch=x64 ;;
  *)
    echo "ensure-dart: unsupported $(uname -s) $(uname -m)" >&2
    exit 1
    ;;
esac

if [[ ! -x $root/bin/dart ]]; then
  tmp="$(mktemp -d)"
  url="https://storage.googleapis.com/dart-archive/channels/stable/release/${version}/sdk/dartsdk-${dart_os}-${dart_arch}-release.zip"
  curl -fsSL -o "$tmp/dart.zip" "$url"
  unzip -q "$tmp/dart.zip" -d "$tmp"
  rm -rf "$root"
  mkdir -p "$(dirname "$root")"
  mv "$tmp/dart-sdk" "$root"
  rm -rf "$tmp"
fi

add_github_path "$root/bin"
if [[ -z ${PUB_CACHE:-} ]]; then
  mkdir -p "$LECA_CACHE/pub/$slot"
  add_github_env PUB_CACHE "$LECA_CACHE/pub/$slot"
fi
