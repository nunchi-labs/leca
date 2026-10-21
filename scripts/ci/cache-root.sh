#!/usr/bin/env bash
# Source this file. Depot mounts /mnt/cache; anywhere else uses the runner temp dir.
if [[ -d /mnt/cache ]]; then
  LECA_CACHE=/mnt/cache
else
  LECA_CACHE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/leca-cache"
  mkdir -p "$LECA_CACHE"
fi

add_github_path() {
  local dir=$1
  if command -v cygpath >/dev/null 2>&1; then
    dir="$(cygpath -w "$dir")"
  fi
  printf '%s\n' "$dir" >> "${GITHUB_PATH:?}"
}

add_github_env() {
  local key=$1 value=$2
  if command -v cygpath >/dev/null 2>&1 && [[ -e $value ]]; then
    value="$(cygpath -w "$value")"
  fi
  printf '%s=%s\n' "$key" "$value" >> "${GITHUB_ENV:?}"
}
