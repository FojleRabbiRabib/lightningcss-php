/*
 * lightningcss-php — C-ABI surface of the Rust shim archive. Every
 * declaration here mirrors an export of native/src/lib.rs; the extension
 * side treats every input to these functions as untrusted.
 * Copyright 2026 Fojle Rabbi (Rabib)
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef LIGHTNINGCSS_PHP_SHIM_H
#define LIGHTNINGCSS_PHP_SHIM_H

#ifdef __cplusplus
extern "C" {
#endif

/* NUL-terminated shim version; static storage, never freed. */
const char *lightningcss_php_shim_version(void);

#ifdef __cplusplus
}
#endif

#endif /* LIGHTNINGCSS_PHP_SHIM_H */
