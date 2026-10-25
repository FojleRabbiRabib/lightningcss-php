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
 * Vendored Lightning CSS revision this build links. "unreleased-skeleton"
 * until the first engine pin lands; recorded here, in the fetch tooling, and
 * in every release artifact, per the pinning policy.
 */
#define PHP_LIGHTNINGCSS_UPSTREAM_PIN "unreleased-skeleton"

extern zend_module_entry lightningcss_module_entry;
#define phpext_lightningcss_ptr &lightningcss_module_entry

#include "php.h"

#endif /* PHP_LIGHTNINGCSS_H */
