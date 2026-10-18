#!/usr/bin/env bash
# Dart on the Depot cache disk.
#
# Pointer: on GitHub Actions run 39159848342 the server job spent 7s in
# dart-lang/setup-dart before a 13s test. That download dies with the
# runner. /mnt/cache is a Depot cache disk (depot/cache-mount, name
# leca-ci-cache), so the next run only checks the version.
set -euo pipefail

version="${DART_VERSION:-3.13.4}"
root="/mnt/cache/dart/${version}"

[[ -d /mnt/cache ]] || {
  echo "ci: /mnt/cache is not mounted. The job mounts leca-ci-cache there." >&2
  exit 1
}

if [[ ! -x $root/bin/dart ]]; then
  tmp="$(mktemp -d)"
  url="https://storage.googleapis.com/dart-archive/channels/stable/release/${version}/sdk/dartsdk-linux-x64-release.zip"
  curl -fsSL -o "$tmp/dart.zip" "$url"
  unzip -q "$tmp/dart.zip" -d "$tmp"
  rm -rf "$root"
  mkdir -p "$(dirname "$root")"
  mv "$tmp/dart-sdk" "$root"
  rm -rf "$tmp"
fi

echo "$root/bin" >> "${GITHUB_PATH:?}"
