#!/usr/bin/env bash
# Linters for scripts/lint.sh.
#
# Pointer: the GitHub "Linters" step was 30s of the 44s lint job
# (CI run 39159848342). apt packages install into /usr and the sandbox
# throws /usr away, so shellcheck, yamllint, cppcheck, xmllint, tidy, jq,
# and ruby still install every run. PowerShell, a JDK, Caddy, actionlint,
# ktlint, cmakelint, rubocop, and PSScriptAnalyzer are unpacked onto
# /mnt/cache and skipped once they are there.
#
# A Depot snapshot (depot/snapshot-action) is the step that removes the
# apt line too. It needs an image name
# <org-id>.registry.depot.dev/leca-lint:latest from `depot org list`.
# Do not point the job at that image until the snapshot has been pushed.
set -euo pipefail

prefix=/mnt/cache/lint
bindir=$prefix/bin

[[ -d /mnt/cache ]] || {
  echo "ci: /mnt/cache is not mounted. The job mounts leca-ci-cache there." >&2
  exit 1
}
mkdir -p "$bindir" "$prefix/gems" "$prefix/modules"

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  shellcheck yamllint cppcheck libxml2-utils jq tidy \
  ruby python3 python3-venv ca-certificates curl tar gzip unzip

fetch_exe() {
  local dest=$1 url=$2
  [[ -x $dest ]] && return 0
  curl -fsSL -o "$dest" "$url"
  chmod +x "$dest"
}

if [[ ! -x $bindir/actionlint ]]; then
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/actionlint.tar.gz" \
    https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_linux_amd64.tar.gz
  tar -xzf "$tmp/actionlint.tar.gz" -C "$tmp" actionlint
  install -m 755 "$tmp/actionlint" "$bindir/actionlint"
  rm -rf "$tmp"
fi

fetch_exe "$bindir/ktlint" \
  https://github.com/pinterest/ktlint/releases/download/1.5.0/ktlint

if [[ ! -x $prefix/jdk/bin/java ]]; then
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/jdk.tar.gz" \
    https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse
  mkdir -p "$prefix/jdk"
  tar -xzf "$tmp/jdk.tar.gz" -C "$prefix/jdk" --strip-components=1
  rm -rf "$tmp"
fi

if [[ ! -x $prefix/pwsh/pwsh ]]; then
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/pwsh.tar.gz" \
    https://github.com/PowerShell/PowerShell/releases/download/v7.6.7/powershell-7.6.7-linux-x64.tar.gz
  mkdir -p "$prefix/pwsh"
  tar -xzf "$tmp/pwsh.tar.gz" -C "$prefix/pwsh"
  rm -rf "$tmp"
fi

if [[ ! -x $bindir/caddy ]]; then
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/caddy.tar.gz" \
    https://github.com/caddyserver/caddy/releases/download/v2.11.7/caddy_2.11.7_linux_amd64.tar.gz
  tar -xzf "$tmp/caddy.tar.gz" -C "$tmp" caddy
  install -m 755 "$tmp/caddy" "$bindir/caddy"
  rm -rf "$tmp"
fi

if [[ ! -x $prefix/py/bin/cmakelint ]]; then
  rm -rf "$prefix/py"
  python3 -m venv "$prefix/py"
  "$prefix/py/bin/pip" install cmakelint
fi

if [[ ! -x $prefix/gems/bin/rubocop ]]; then
  sudo apt-get install -y --no-install-recommends ruby-dev build-essential
  GEM_HOME=$prefix/gems gem install rubocop --no-document
fi

if [[ ! -d $prefix/modules/PSScriptAnalyzer ]]; then
  "$prefix/pwsh/pwsh" -NoProfile -Command \
    "Set-PSRepository PSGallery -InstallationPolicy Trusted
     Save-Module PSScriptAnalyzer -Path '$prefix/modules' -Force"
fi

{
  echo "$bindir"
  echo "$prefix/jdk/bin"
  echo "$prefix/pwsh"
  echo "$prefix/gems/bin"
  echo "$prefix/py/bin"
} >> "${GITHUB_PATH:?}"

{
  echo "JAVA_HOME=$prefix/jdk"
  echo "GEM_HOME=$prefix/gems"
  echo "PSModulePath=$prefix/modules"
} >> "${GITHUB_ENV:?}"
