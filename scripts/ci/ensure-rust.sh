#!/usr/bin/env bash
# Rustup for one CI job. Respects CARGO_HOME and RUSTUP_HOME when the
# workflow already set them (the package jobs do).
#
# Usage: ensure-rust.sh <slot>
#   RUSTUP_COMPONENTS  space-separated components, such as "clippy"
#   RUSTUP_TARGETS     space-separated targets, such as "aarch64-apple-ios"
set -euo pipefail

slot="${1:?slot}"
# shellcheck disable=SC1091
source "$(dirname "$0")/cache-root.sh"

export CARGO_HOME="${CARGO_HOME:-$LECA_CACHE/cargo/$slot}"
export RUSTUP_HOME="${RUSTUP_HOME:-$LECA_CACHE/rustup/$slot}"
mkdir -p "$CARGO_HOME" "$RUSTUP_HOME"

if [[ ! -x $CARGO_HOME/bin/rustup ]]; then
  curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path
fi

rustup="$CARGO_HOME/bin/rustup"
if [[ -n ${RUSTUP_COMPONENTS:-} ]]; then
  read -r -a components <<< "$RUSTUP_COMPONENTS"
  "$rustup" component add "${components[@]}"
fi
if [[ -n ${RUSTUP_TARGETS:-} ]]; then
  read -r -a targets <<< "$RUSTUP_TARGETS"
  "$rustup" target add "${targets[@]}"
fi

add_github_path "$CARGO_HOME/bin"
add_github_env CARGO_HOME "$CARGO_HOME"
add_github_env RUSTUP_HOME "$RUSTUP_HOME"
