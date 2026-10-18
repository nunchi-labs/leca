#!/usr/bin/env bash
# Copy release builds into the directory Caddy serves at /downloads/.
#
#   ./scripts/publish-downloads.sh
#
# Publishes whichever of these already exist. It does not build them.
#   build/app/outputs/flutter-apk/app-release.apk  -> leca-android.apk
#   build/linux/x64/release/bundle/                -> leca-linux-x64.zip
#   build/macos/Build/Products/Release/*.app       -> leca-macos.zip
#   build/windows/x64/runner/Release/leca.exe      -> leca-windows.zip
# LECA_WEB_ROOT defaults to /var/www/leca.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dest="${LECA_WEB_ROOT:-/var/www/leca}/downloads"
install -d -m 755 "$dest"

publish_file() {
  local src=$1 name=$2
  [[ -f $src ]] || return 0
  install -m 644 "$src" "$dest/$name"
  echo "published $name"
}

publish_tree() {
  local dir=$1 name=$2
  [[ -d $dir ]] || return 0
  local tmp
  tmp="$(mktemp)"
  rm -f "$tmp"
  (
    cd "$dir"
    zip -qry "$tmp" .
  )
  install -m 644 "$tmp" "$dest/$name"
  rm -f "$tmp"
  echo "published $name"
}

publish_file \
  "$root/build/app/outputs/flutter-apk/app-release.apk" \
  leca-android.apk

if [[ -x $root/build/linux/x64/release/bundle/leca ]]; then
  publish_tree "$root/build/linux/x64/release/bundle" leca-linux-x64.zip
fi

if [[ -d $root/build/macos/Build/Products/Release/Leca.app ]]; then
  tmp="$(mktemp)"
  rm -f "$tmp"
  (
    cd "$root/build/macos/Build/Products/Release"
    zip -qry -y "$tmp" Leca.app
  )
  install -m 644 "$tmp" "$dest/leca-macos.zip"
  rm -f "$tmp"
  echo "published leca-macos.zip"
fi

if [[ -f $root/build/windows/x64/runner/Release/leca.exe ]]; then
  publish_tree "$root/build/windows/x64/runner/Release" leca-windows.zip
fi

chmod -R a+rX "$dest"
