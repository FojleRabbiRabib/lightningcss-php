/*
 * lightningcss-php — module header. declares the module entry, the build
 * version, and the vendored upstream pin recorded on every release.
 * Copyright 2026 Fojle Rabbi (Rabib)
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef PHP_LIGHTNINGCSS_H
#define PHP_LIGHTNINGCSS_H

#define PHP_LIGHTNINGCSS_VERSION "0.1.0"

/*
 * Vendored Lightning CSS revision this build links: release 1.33.0 (crate
 * 1.0.0-alpha.72), pinned and SHA-256 verified by tools/fetch-lightningcss.sh
 * and locked to the same browserslist data versions as upstream's own lock.
 * Recorded here, in the fetch tooling, and in every release artifact, per
 * the pinning policy.
 */
#define PHP_LIGHTNINGCSS_UPSTREAM_PIN "1.33.0"

extern zend_module_entry lightningcss_module_entry;
#define phpext_lightningcss_ptr &lightningcss_module_entry

#include "php.h"

#endif /* PHP_LIGHTNINGCSS_H */
