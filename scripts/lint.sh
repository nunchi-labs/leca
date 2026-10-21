#!/usr/bin/env bash
# Strict checks for every language in this tree except Dart.
# Dart is flutter analyze / dart analyze, in their own CI jobs.
#
# Usage: scripts/lint.sh [check ...]
#   no arguments, or "all", runs every check.
#   one name runs that check. The names match the CI matrix.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
# The checkout may be owned by another user. This does not write git config.
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0="$root"

checks=(
  shellcheck
  yamllint
  actionlint
  json
  xml
  html
  caddy
  systemd
  cppcheck
  cmakelint
  ktlint
  powershell
  ruby
)

tracked() {
  git ls-files -z "$@"
}

run_shellcheck() {
  local shell_files=()
  mapfile -d '' shell_files < <(tracked '*.sh')
  [[ ${#shell_files[@]} -eq 0 ]] && return 0
  shellcheck -S style -s bash "${shell_files[@]}"
}

run_yamllint() {
  local yaml_files=()
  mapfile -d '' yaml_files < <(tracked '*.yml' '*.yaml')
  [[ ${#yaml_files[@]} -eq 0 ]] && return 0
  yamllint -s "${yaml_files[@]}"
}

run_actionlint() {
  local action_files=()
  mapfile -d '' action_files < <(tracked '.github/workflows/*.yml' '.github/workflows/*.yaml' '.depot/workflows/*.yml' '.depot/workflows/*.yaml')
  [[ ${#action_files[@]} -eq 0 ]] && return 0
  actionlint -no-color "${action_files[@]}"
}

run_json() {
  local file
  while IFS= read -r -d '' file; do
    jq empty "$file"
  done < <(tracked '*.json' '*.arb')
}

run_xml() {
  local file
  while IFS= read -r -d '' file; do
    xmllint --noout "$file"
  done < <(tracked '*.xml' '*.plist' '*.entitlements' '*.storyboard' '*.xib')
}

run_html() {
  tidy -qe -utf8 web/index.html
  tidy -qe -utf8 host/download.html
}

run_caddy() {
  caddy fmt --diff host/Caddyfile >/dev/null
}

run_systemd() {
  local systemd_out filtered
  if ! command -v systemd-analyze >/dev/null 2>&1; then
    echo "systemd-analyze is not installed" >&2
    exit 1
  fi
  # The unit's dart binary is installed on the server, not on the CI runner.
  # A container has no systemd bus. Those two are the environment, not the unit.
  if systemd_out="$(systemd-analyze verify host/leca-auth.service 2>&1)"; then
    return 0
  fi
  # The unit names paths that exist on the server, not on a CI runner.
  filtered="$(
    printf '%s\n' "$systemd_out" \
      | grep -v \
        -e 'is not executable: No such file or directory' \
        -e 'Failed to connect to .*bus' \
        -e 'System has not been booted with systemd' \
        -e 'Host and machine IDs are not initialized' \
        -e 'WorkingDirectory=.*does not exist' \
        -e 'leca-auth.env' \
        -e '/root/leca/server' \
      || true
  )"
  if [[ -n $filtered ]]; then
    printf '%s\n' "$systemd_out"
    exit 1
  fi
}

run_cppcheck() {
  cppcheck --enable=all --error-exitcode=1 --inline-suppr \
    --suppressions-list=cppcheck.suppress \
    -i linux/flutter -i windows/flutter \
    linux windows ios/Runner/Runner-Bridging-Header.h
}

run_cmakelint() {
  local cmake_files=() kept=() file
  mapfile -d '' cmake_files < <(tracked 'CMakeLists.txt' '**/CMakeLists.txt' '*.cmake')
  for file in "${cmake_files[@]}"; do
    [[ $file == */flutter/* ]] && continue
    kept+=("$file")
  done
  [[ ${#kept[@]} -eq 0 ]] && return 0
  cmakelint --filter=-whitespace/indent,-linelength,-readability/logic "${kept[@]}"
}

run_ktlint() {
  ktlint --reporter=plain --relative "android/**/*.kt" "android/**/*.kts"
}

run_powershell() {
  pwsh -NoProfile -File scripts/lint-powershell.ps1
}

run_ruby() {
  rubocop --fail-level convention
}

run_named() {
  case "$1" in
    shellcheck) run_shellcheck ;;
    yamllint) run_yamllint ;;
    actionlint) run_actionlint ;;
    json) run_json ;;
    xml) run_xml ;;
    html) run_html ;;
    caddy) run_caddy ;;
    systemd) run_systemd ;;
    cppcheck) run_cppcheck ;;
    cmakelint) run_cmakelint ;;
    ktlint) run_ktlint ;;
    powershell) run_powershell ;;
    ruby) run_ruby ;;
    *)
      echo "lint: unknown check $1" >&2
      exit 1
      ;;
  esac
}

if [[ $# -eq 0 ]]; then
  set -- all
fi

for name in "$@"; do
  if [[ $name == all ]]; then
    for check in "${checks[@]}"; do
      echo "$check"
      run_named "$check"
    done
  else
    echo "$name"
    run_named "$name"
  fi
done

echo "lint ok"
