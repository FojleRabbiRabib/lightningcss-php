#!/usr/bin/env bash
# lightningcss-php — pinned, SHA-256-verified fetch of the vendored Lightning CSS
# sources into gitignored vendor-src/, plus the hermetic cargo vendor tree the
# shim's builds resolve from. Refuses a hash mismatch; records nothing into
# git. The pin is bumped only through the documented bump drill.
# Copyright 2026 Fojle Rabbi (Rabib)
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
export PATH="$HOME/.cargo/bin:$PATH"

# Pinned upstream release (verified against the upstream tag list on the pin
# date recorded below). Bump via the drill: changelog + advisories first, then
# this line, the hash below, and php_lightningcss.h together.
PIN="1.33.0"
PIN_DATE="2026-10-23"
EXPECTED_SHA256="3197aa5188b66d0d1e5026cbc8b65c4c0c53fdc949f9ed497fe75df2d13f722a"

root="$(cd "$(dirname "$0")/.." && pwd)"
dest="${root}/vendor-src/lightningcss-${PIN}"
tarball="${root}/vendor-src/lightningcss-${PIN}.tar.gz"
vendored="${root}/vendor-src/cargo-vendor"
vendored_marker="${vendored}/.verified-cargo-vendor"

mkdir -p "${root}/vendor-src"

# A fetched tree is trusted only while its verification marker matches the pin;
# an interrupted extraction or corrupted directory fails loudly instead of
# being silently reused.
if [[ -d "${dest}" ]]; then
    if [[ -f "${dest}/.verified-source-sha256" ]] \
        && [[ "$(cat "${dest}/.verified-source-sha256")" = "$EXPECTED_SHA256" ]]; then
        echo "already fetched and verified: ${dest} (pin ${PIN} dated ${PIN_DATE})"
    else
        echo "FAIL: ${dest} exists without a matching .verified-source-sha256 marker" >&2
        echo "      remove it and re-run this script" >&2
        exit 1
    fi
else
    url="https://codeload.github.com/parcel-bundler/lightningcss/tar.gz/refs/tags/v${PIN}"
    curl -fsSL "$url" -o "$tarball"

    actual="$(sha256sum "$tarball" | awk '{ print $1 }')"
    if [[ "$actual" != "$EXPECTED_SHA256" ]]; then
        echo "FAIL: SHA-256 mismatch for ${PIN}" >&2
        echo "  expected: ${EXPECTED_SHA256}" >&2
        echo "  actual:   ${actual}" >&2
        rm -f "$tarball"
        exit 1
    fi

    mkdir -p "${dest}"
    tar -xzf "$tarball" -C "${dest}" --strip-components=1
    printf '%s\n' "$EXPECTED_SHA256" > "${dest}/.verified-source-sha256"
    rm -f "$tarball"
    echo "FETCHED: lightningcss ${PIN} dated ${PIN_DATE} (verified ${EXPECTED_SHA256})"
fi

# The hermetic vendor tree: exactly the crates in native/Cargo.lock, resolved
# from the network once here so every later build runs --offline. Trusted on
# the same marker pattern as the engine sources, and the marker records the
# lockfile hash it was built from — a Cargo.lock bump without a re-vendor
# fails loudly instead of building against a stale tree.
cargo_config="${root}/native/.cargo/config.toml"
if [[ ! -f "${cargo_config}" ]]; then
    echo "FAIL: ${cargo_config} is missing; it is a tracked part of the source" >&2
    echo "      replacement and the build is not hermetic without it" >&2
    exit 1
fi

lock_hash="$(sha256sum "${root}/native/Cargo.lock" | awk '{ print $1 }')"

if [[ -f "${vendored_marker}" ]]; then
    if [[ "$(sed -n 's/^lockfile-sha256=//p' "${vendored_marker}")" = "${lock_hash}" ]]; then
        echo "already vendored: ${vendored}"
        exit 0
    fi
    echo "FAIL: ${vendored} was vendored from a different native/Cargo.lock" >&2
    echo "      remove ${vendored} and re-run this script to re-vendor" >&2
    exit 1
fi
if [[ -e "${vendored}" ]]; then
    echo "FAIL: ${vendored} exists without its .verified-cargo-vendor marker" >&2
    echo "      remove it and re-run this script" >&2
    exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
    echo "FAIL: cargo not found; install rustup to vendor the crate tree" >&2
    exit 1
fi

(cd "${root}/native" && cargo vendor --locked "${vendored}" >/dev/null)
printf 'lockfile-sha256=%s\n' "${lock_hash}" > "${vendored_marker}"
echo "VENDORED: ${vendored} (locked to native/Cargo.lock)"
