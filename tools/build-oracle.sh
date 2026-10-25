#!/usr/bin/env bash
# lightningcss-php — builds the upstream lightningcss CLI binary from the
# pinned vendored tree. The CLI is the fidelity oracle: the CSS fidelity gate
# compares the extension's output byte-for-byte against this binary for the
# same (input CSS, option set) fixture rows.
# Copyright 2026 Fojle Rabbi (Rabib)
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
export PATH="$HOME/.cargo/bin:$PATH"

root="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v cargo >/dev/null 2>&1; then
    echo "FAIL: cargo not found; install rustup" >&2
    exit 1
fi

tree="$(find "${root}/vendor-src" -maxdepth 1 -type d -name 'lightningcss-*' 2>/dev/null | sort | head -1 || true)"
if [[ -z "$tree" ]]; then
    echo "FAIL: no vendored tree under vendor-src/ — run tools/fetch-lightningcss.sh first" >&2
    exit 1
fi

cargo build --release --locked --manifest-path "${tree}/Cargo.toml" -p lightningcss --bin lightningcss --features cli
echo "ORACLE: ${tree}/target/release/lightningcss"
"${tree}/target/release/lightningcss" --version
echo "ORACLE BUILT"
