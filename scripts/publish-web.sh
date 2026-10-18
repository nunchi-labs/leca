#!/usr/bin/env bash
# Build the web app and publish it where Caddy serves /app/.
#
#   ./scripts/publish-web.sh
#
# LECA_AUTH_API defaults to origin: the page calls the host that served it.
# Set LECA_AUTH_API=https://leca.world to pin the API instead.
# LECA_WEB_ROOT defaults to /var/www/leca.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/opt/flutter/bin:${PATH}"
auth="${LECA_AUTH_API:-origin}"
dest="${LECA_WEB_ROOT:-/var/www/leca}"

cd "$root"
flutter pub get
flutter build web --release --base-href /app/ \
  --dart-define="AUTH_API=${auth}"

install -d -m 755 "$dest/web" "$dest/fonts" "$dest/downloads"
rsync -a --delete "$root/build/web/" "$dest/web/"
install -m 644 "$root/host/download.html" "$dest/download.html"
install -m 644 "$root/web/favicon.png" "$dest/favicon.png"
install -m 644 "$root/assets/fonts/"*.ttf "$dest/fonts/"
"$root/scripts/publish-downloads.sh"
chmod -R a+rX "$dest"
echo "published ${dest} (AUTH_API=${auth})"
