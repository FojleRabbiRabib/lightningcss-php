#!/usr/bin/env bash
# lightningcss-php — multi-ABI build driver. Stages tracked sources into each
# build/<ver> tree, runs phpize + configure with that ABI's php-config, builds,
# gates ELF hardening on the resulting modules/lightningcss.so, and verifies an
# explicit load — all before printing an OK line. Refuses any ABI whose
# toolchain is missing rather than skipping it. Never runs make install (the
# system extension dir is root-owned).
# Copyright 2026 Fojle Rabbi (Rabib)
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
jobs="$(nproc)"
failed=()

# Tracked source set staged into each per-ABI build directory.
# Staging keeps the root clean and gives phpize the in-tree config.m4 it requires.
EXT_SOURCES=(
    config.m4
    Makefile.frag
    lightningcss.map
    php_lightningcss.h
    lightningcss_internal.h
    lightningcss_arginfo.h
    lightningcss.stub.php
    lightningcss.c
    lightningcss_exception.c
)

# Export pointers back to root/native so the staged build finds the Rust bridge
# even though $abs_srcdir is build/<ver>.
export LIGHTNINGCSS_SHIM_INCLUDE="${root}/native/include"
export LIGHTNINGCSS_NATIVE_DIR="${root}/native"

# Ensure rustup tools are on PATH if installed to ~/.cargo/bin
export PATH="$HOME/.cargo/bin:$PATH"

# DEBUG=1 handling: pre-build the cargo profile and export the archive path.
# --offline: the build is hermetic — crates resolve from the verified vendor
# tree (native/.cargo/config.toml source replacement), never the network.
if [[ "${DEBUG:-0}" = "1" ]]; then
    export LIGHTNINGCSS_DEBUG=1
    export LIGHTNINGCSS_ARCHIVE="${root}/native/target/debug/liblightningcss_php.a"
    (cd "${root}/native" && cargo build --locked --offline)
else
    export LIGHTNINGCSS_DEBUG=0
    export LIGHTNINGCSS_ARCHIVE="${root}/native/target/release/liblightningcss_php.a"
    (cd "${root}/native" && cargo build --release --locked --offline)
fi

TARGET_VER="${1:-${PHP_VERSION:-all}}"
if [[ "$TARGET_VER" = "all" ]]; then
    VERSIONS=(8.3 8.4 8.5)
else
    case "$TARGET_VER" in
        8.3|8.4|8.5) VERSIONS=("$TARGET_VER") ;;
        *) echo "FAIL: unsupported version '$TARGET_VER' (expected: 8.3, 8.4, 8.5, or all)" >&2; exit 2 ;;
    esac
fi

for ver in "${VERSIONS[@]}"; do
    php_bin="php${ver}"
    php_config="php-config${ver}"
    phpize_bin="phpize${ver}"

    if command -v "$php_bin" >/dev/null 2>&1 \
        && command -v "$php_config" >/dev/null 2>&1 \
        && command -v "$phpize_bin" >/dev/null 2>&1; then
        php_bin="$(command -v "$php_bin")"
        php_config="$(command -v "$php_config")"
        phpize_bin="$(command -v "$phpize_bin")"
    elif [[ -x "/usr/bin/php${ver}" ]] \
        && [[ -x "/usr/bin/php-config${ver}" ]] \
        && [[ -x "/usr/bin/phpize${ver}" ]]; then
        php_bin="/usr/bin/php${ver}"
        php_config="/usr/bin/php-config${ver}"
        phpize_bin="/usr/bin/phpize${ver}"
    elif command -v php >/dev/null 2>&1 \
        && [[ "$(php -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;' 2>/dev/null)" = "$ver" ]] \
        && command -v php-config >/dev/null 2>&1 && command -v phpize >/dev/null 2>&1; then
        php_bin="$(command -v php)"
        php_config="$(command -v php-config)"
        phpize_bin="$(command -v phpize)"
    else
        echo "FAIL: php ${ver} toolchain missing" >&2
        failed+=("${ver}:toolchain")
        continue
    fi

    build_dir="${root}/build/${ver}"
    mkdir -p "$build_dir"

    # Stage sources into the build dir
    for f in "${EXT_SOURCES[@]}"; do
        cp -p "${root}/${f}" "${build_dir}/${f}"
    done

    cd "$build_dir"
    "$phpize_bin" > phpize.log 2>&1 || { tail -20 phpize.log; failed+=("${ver}:phpize"); cd "$root"; continue; }
    ./configure --enable-lightningcss --with-php-config="$php_config" > configure.log 2>&1 \
        || { tail -30 configure.log; failed+=("${ver}:configure"); cd "$root"; continue; }
    make -j "$jobs" > make.log 2>&1 || { tail -40 make.log; failed+=("${ver}:make"); cd "$root"; continue; }

    out="${build_dir}/modules/lightningcss.so"
    if [[ ! -f "$out" ]]; then
        echo "FAIL: ${out} not produced" >&2
        failed+=("${ver}:artifact-missing")
        cd "$root"
        continue
    fi

    # Gate the built artifact before reporting OK
    "${root}/tools/elf-gates.sh" "$out" || { failed+=("${ver}:elf-gates"); cd "$root"; continue; }

    # Verify explicit load
    "$php_bin" -n -d extension="$out" -r 'exit(extension_loaded("lightningcss") ? 0 : 1);' \
        || { failed+=("${ver}:load"); cd "$root"; continue; }

    echo "OK: ${ver} -> ${out}"
    cd "$root"
done

if [[ "${#failed[@]}" -gt 0 ]]; then
    echo "BUILD FAILED: ${failed[*]}" >&2
    exit 1
fi
echo "ALL ABIs BUILT"
