#!/usr/bin/env bash
# One Flutter SDK per job, on the Depot cache disk.
#
# Pointer: jobs must not share a slot. precache writes the SDK directory,
# and parallel writers corrupt it. GitHub's flutter-action step was 25s on
# the app job and 2m 8s for the ARM Windows checkout (CI run 39159848342).
# The disk keeps the clone. The first run of each slot still pays for it.
#
# Usage: ensure-flutter.sh <slot> <precache>
#   precache is "host", or a flutter precache flag without the dashes
#   (linux, android, web).
set -euo pipefail

slot="${1:?slot}"
precache="${2:?precache}"
version="${FLUTTER_VERSION:-3.47.5}"
sdk="/mnt/cache/flutter/${slot}/sdk"

[[ -d /mnt/cache ]] || {
  echo "ci: /mnt/cache is not mounted. The job mounts leca-ci-cache there." >&2
  exit 1
}

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

echo "$sdk/bin" >> "${GITHUB_PATH:?}"
