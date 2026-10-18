#!/usr/bin/env bash
# Strict checks for every language in this tree except Dart.
# Dart is flutter analyze / dart analyze in the CI app and server jobs.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
# The checkout may be owned by another user. This does not write git config.
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0="$root"

tracked() {
  git ls-files -z "$@"
}

echo "shellcheck"
mapfile -d '' shell_files < <(tracked '*.sh')
shellcheck -S style -s bash "${shell_files[@]}"

echo "yamllint"
mapfile -d '' yaml_files < <(tracked '*.yml' '*.yaml')
yamllint -s "${yaml_files[@]}"

echo "actionlint"
actionlint -no-color

echo "json"
while IFS= read -r -d '' file; do
  jq empty "$file"
done < <(tracked '*.json' '*.arb')

echo "xml"
while IFS= read -r -d '' file; do
  xmllint --noout "$file"
done < <(tracked '*.xml' '*.plist' '*.entitlements' '*.storyboard' '*.xib')

echo "html"
tidy -qe -utf8 web/index.html
tidy -qe -utf8 host/download.html

echo "caddy"
caddy fmt --diff host/Caddyfile >/dev/null

echo "systemd"
systemd-analyze verify host/leca-auth.service

echo "cppcheck"
cppcheck --enable=all --error-exitcode=1 --inline-suppr \
  --suppressions-list=cppcheck.suppress \
  -i linux/flutter -i windows/flutter \
  linux windows ios/Runner/Runner-Bridging-Header.h

echo "cmakelint"
mapfile -d '' cmake_files < <(tracked 'CMakeLists.txt' '**/CMakeLists.txt' '*.cmake')
kept=()
for file in "${cmake_files[@]}"; do
  [[ $file == */flutter/* ]] && continue
  kept+=("$file")
done
cmakelint --filter=-whitespace/indent,-linelength,-readability/logic "${kept[@]}"

echo "ktlint"
ktlint --reporter=plain --relative "android/**/*.kt" "android/**/*.kts"

echo "powershell"
pwsh -NoProfile -File scripts/lint-powershell.ps1

echo "ruby"
rubocop --fail-level convention

echo "lint ok"
