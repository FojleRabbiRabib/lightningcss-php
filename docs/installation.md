# Installing lightningcss-php

## Prerequisites

| Requirement | Notes |
|---|---|
| PHP 8.3 / 8.4 / 8.5 | With development headers (`php8.x-dev` on Debian/Ubuntu, `php-devel` on RHEL-family). One extension binary is built per ABI. |
| Rust toolchain >= 1.75 | Installed via [rustup](https://rustup.rs). The floor rises when the vendored engine lands; `./configure` enforces it. |
| C compiler | GCC or Clang with C99 support. The build uses `-Wall -Wextra -Werror` — a clean toolchain is required. |
| make / autotools | Standard `phpize` toolchain. |

## Fast path: the build driver

`tools/build.sh` builds every installed ABI in turn (8.3 first, then 8.4, then 8.5),
staging each build into its own `build/<ver>/` tree so the repository root stays clean.
Each artifact is ELF-hardness-gated and load-tested before the driver reports OK:

```bash
tools/build.sh
# OK: 8.3 -> .../build/8.3/modules/lightningcss.so
# OK: 8.4 -> ...
# OK: 8.5 -> ...
# ALL ABIs BUILT
```

A `DEBUG=1` environment produces an unstripped `-g -O0` build for Valgrind/gdb frame
resolution:

```bash
DEBUG=1 tools/build.sh
```

## Manual path: plain phpize

Equivalent to what PIE/PECL/distro source builds run:

```bash
phpize8.3
./configure --enable-lightningcss
make -j"$(nproc)"
make install   # optional; needs write access to the extension dir
```

`./configure` performs these checks in order:

1. **cargo presence and MSRV** — refuses a toolchain older than 1.75 with an actionable
   message; falls back from a PATH cargo to `~/.cargo/bin/cargo` before failing.
2. **shim header** — `native/include/lightningcss_php_shim.h` must exist.
3. **hardening probes** — `-fstack-clash-protection` and `_FORTIFY_SOURCE=3`/`=2`, each
   compiled with `-Werror` so warning-level rejections cannot become runtime breakage.
4. **link map** — `lightningcss.map` must exist; the link enforces that only `get_module`
   is exported from the final `.so`.

## Enabling and verifying

```bash
# add to php.ini (path from: php-config8.3 --extension-dir)
extension=lightningcss.so

php8.3 -m | grep lightningcss
php8.3 --ri lightningcss
```

`--ri` output shows the extension version, the vendored upstream pin, the shim version,
and the current INI values.

## PIE / Composer

`composer.json` declares `type: php-ext`, so PIE can install the package:

```bash
pie install lightningcss-php/lightningcss
```

Prebuilt per-ABI binaries are attached to GitHub releases when a version is tagged.

## Clean rebuild / uninstall

```bash
make clean          # in the build tree
phpize --clean      # removes generated build files
# remove the installed extension:
rm "$(php-config8.3 --extension-dir)/lightningcss.so"
```
