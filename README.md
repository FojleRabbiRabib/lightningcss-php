# lightningcss-php

Lightning CSS in-process for PHP: transform, minify, bundle, and generate source maps
without installing Node.js, npm, or PostCSS.

Backed by a statically linked build of the spec-grade
[Lightning CSS](https://github.com/parcel-bundler/lightningcss) engine (Rust, MPL-2.0).

## Current status

**Skeleton (v0.1.0 pre-release):** multi-ABI build, Rust shim crate, symbol-isolated
linking, PIE package manifest, and the base extension surface (`Lightningcss\Exception`,
`lightningcss.max_input_bytes` INI). The CSS processing surface (transform, minify, bundle,
source maps) is being implemented next; every capability will be proposed before landing.

## Requirements

- PHP 8.3, 8.4, or 8.5 (development headers required for source builds)
- Rust toolchain >= 1.75 (managed via [rustup](https://rustup.rs))
- C compiler with C99 support (GCC or Clang)
- Linux (x86_64, aarch64)

## Installation

### From source

```bash
# Multi-ABI build (builds all installed PHP versions):
tools/build.sh

# Or single-version build via phpize:
phpize8.3
./configure --enable-lightningcss
make -j"$(nproc)"
# The built extension is in modules/lightningcss.so
```

See [`docs/installation.md`](docs/installation.md) for full prerequisites, configure
options, and troubleshooting.

### PIE / Composer

`composer.json` declares `type: php-ext` for PIE (PHP Installer for Extensions) support:

```bash
pie install lightningcss-php/lightningcss
```

## Base surface

- `Lightningcss\Exception`: the base exception type every extension failure extends.
- `lightningcss.max_input_bytes`: INI setting bounding input stylesheet size (default
  `16777216` = 16 MiB). Configurable in `php.ini` or via `ini_set()`.

Full options and contracts will be documented in [`docs/usage.md`](docs/usage.md).

## Security

See [`docs/security.md`](docs/security.md) for the threat model, untrusted-input handling,
and vulnerability reporting.

## Licence

The extension code is licensed under the **Apache License, Version 2.0** (the `LICENSE`
file).

The vendored Lightning CSS engine is licensed under the **Mozilla Public License,
Version 2.0**. Statically linked release artifacts record the exact upstream pin; see
[`NOTICE`](NOTICE) for details.
