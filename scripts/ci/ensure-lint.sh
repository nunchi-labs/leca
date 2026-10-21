#!/usr/bin/env bash
# Install the tools for one scripts/lint.sh check.
#
# Usage: ensure-lint.sh <check>
# Apt packages install every run. Binaries unpack onto the CI cache.
set -euo pipefail

check="${1:?check}"
export DEBIAN_FRONTEND=noninteractive
# shellcheck disable=SC1091
source "$(dirname "$0")/cache-root.sh"

prefix="$LECA_CACHE/lint"
bindir="$prefix/bin"
mkdir -p "$bindir" "$prefix/gems" "$prefix/modules"

host_arch() {
  case "$(uname -m)" in
    aarch64 | arm64) echo arm64 ;;
    *) echo amd64 ;;
  esac
}

apt_install() {
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends "$@"
}

fetch_exe() {
  local dest=$1 url=$2
  [[ -x $dest ]] && return 0
  curl -fsSL -o "$dest" "$url"
  chmod +x "$dest"
}

install_actionlint() {
  [[ -x $bindir/actionlint ]] && return 0
  local tmp arch
  arch="$(host_arch)"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/actionlint.tar.gz" \
    "https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_linux_${arch}.tar.gz"
  tar -xzf "$tmp/actionlint.tar.gz" -C "$tmp" actionlint
  install -m 755 "$tmp/actionlint" "$bindir/actionlint"
  rm -rf "$tmp"
}

install_jdk() {
  [[ -x $prefix/jdk/bin/java ]] && return 0
  local tmp arch=x64
  if [[ $(uname -m) == aarch64 || $(uname -m) == arm64 ]]; then
    arch=aarch64
  fi
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/jdk.tar.gz" \
    "https://api.adoptium.net/v3/binary/latest/21/ga/linux/${arch}/jdk/hotspot/normal/eclipse"
  mkdir -p "$prefix/jdk"
  tar -xzf "$tmp/jdk.tar.gz" -C "$prefix/jdk" --strip-components=1
  rm -rf "$tmp"
}

install_pwsh() {
  [[ -x $prefix/pwsh/pwsh ]] && return 0
  local tmp arch
  arch="$(host_arch)"
  if [[ $arch == amd64 ]]; then
    arch=x64
  fi
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/pwsh.tar.gz" \
    "https://github.com/PowerShell/PowerShell/releases/download/v7.6.7/powershell-7.6.7-linux-${arch}.tar.gz"
  mkdir -p "$prefix/pwsh"
  tar -xzf "$tmp/pwsh.tar.gz" -C "$prefix/pwsh"
  rm -rf "$tmp"
}

install_caddy() {
  [[ -x $bindir/caddy ]] && return 0
  local tmp arch
  arch="$(host_arch)"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/caddy.tar.gz" \
    "https://github.com/caddyserver/caddy/releases/download/v2.11.7/caddy_2.11.7_linux_${arch}.tar.gz"
  tar -xzf "$tmp/caddy.tar.gz" -C "$tmp" caddy
  install -m 755 "$tmp/caddy" "$bindir/caddy"
  rm -rf "$tmp"
}

case "$check" in
  shellcheck) apt_install shellcheck ;;
  yamllint) apt_install yamllint ;;
  actionlint)
    apt_install ca-certificates curl tar gzip
    install_actionlint
    add_github_path "$bindir"
    ;;
  json) apt_install jq ;;
  xml) apt_install libxml2-utils ;;
  html) apt_install tidy ;;
  caddy)
    apt_install ca-certificates curl tar gzip
    install_caddy
    add_github_path "$bindir"
    ;;
  systemd) apt_install systemd ;;
  cppcheck) apt_install cppcheck ;;
  cmakelint)
    apt_install python3 python3-venv ca-certificates
    if [[ ! -x $prefix/py/bin/cmakelint ]]; then
      rm -rf "$prefix/py"
      python3 -m venv "$prefix/py"
      "$prefix/py/bin/pip" install cmakelint
    fi
    add_github_path "$prefix/py/bin"
    ;;
  ktlint)
    apt_install ca-certificates curl tar gzip
    install_jdk
    fetch_exe "$bindir/ktlint" \
      https://github.com/pinterest/ktlint/releases/download/1.5.0/ktlint
    add_github_path "$bindir"
    add_github_path "$prefix/jdk/bin"
    add_github_env JAVA_HOME "$prefix/jdk"
    ;;
  powershell)
    apt_install ca-certificates curl tar gzip
    install_pwsh
    if [[ ! -d $prefix/modules/PSScriptAnalyzer ]]; then
      "$prefix/pwsh/pwsh" -NoProfile -Command \
        "Set-PSRepository PSGallery -InstallationPolicy Trusted
         Save-Module PSScriptAnalyzer -Path '$prefix/modules' -Force"
    fi
    add_github_path "$prefix/pwsh"
    add_github_env PSModulePath "$prefix/modules"
    ;;
  ruby)
    apt_install ruby ruby-dev build-essential
    if [[ ! -x $prefix/gems/bin/rubocop ]]; then
      GEM_HOME=$prefix/gems gem install rubocop -v 1.92.0 --no-document
    fi
    add_github_path "$prefix/gems/bin"
    add_github_env GEM_HOME "$prefix/gems"
    ;;
  *)
    echo "ensure-lint: unknown check $check" >&2
    exit 1
    ;;
esac
