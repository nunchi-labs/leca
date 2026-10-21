#!/usr/bin/env bash
# One Flutter SDK per job.
#
# Pointer: jobs must not share a slot. precache writes the SDK directory,
# and parallel writers corrupt it.
#
# Usage: ensure-flutter.sh <slot> <precache>
#   precache is "host", or a flutter precache flag without the dashes
#   (linux, android, web, macos, ios, windows).
set -euo pipefail

slot="${1:?slot}"
precache="${2:?precache}"
version="${FLUTTER_VERSION:-3.47.5}"
# shellcheck disable=SC1091
source "$(dirname "$0")/cache-root.sh"
sdk="$LECA_CACHE/flutter/${slot}/sdk"

got=""
if [[ -x $sdk/bin/flutter ]]; then
  got="$("$sdk/bin/flutter" --version 2>/dev/null | awk '/^Flutter / { print $2; exit }')"
fi

if [[ $got != "$version" ]]; then
  rm -rf "$sdk"
  mkdir -p "$(dirname "$sdk")"
  git clone --depth 1 --branch "$version" https://github.com/flutter/flutter.git "$sdk"
  "$sdk/bin/flutter" config --no-analytics
  if [[ $precache == host ]]; then
    "$sdk/bin/flutter" precache
  else
    "$sdk/bin/flutter" precache "--${precache}"
  fi
fi

add_github_path "$sdk/bin"
if [[ -z ${PUB_CACHE:-} ]]; then
  mkdir -p "$LECA_CACHE/pub/$slot"
  add_github_env PUB_CACHE "$LECA_CACHE/pub/$slot"
fi
