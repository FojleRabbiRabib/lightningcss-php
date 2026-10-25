/*
 * lightningcss-php — internal declarations shared between translation units:
 * module globals, INI entry names, and internal class registration.
 * Copyright 2026 Fojle Rabbi (Rabib)
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef LIGHTNINGCSS_INTERNAL_H
#define LIGHTNINGCSS_INTERNAL_H

#define LIGHTNINGCSS_INI_MAX_INPUT_BYTES "lightningcss.max_input_bytes"
#define LIGHTNINGCSS_DEFAULT_MAX_INPUT_BYTES ((zend_long)16777216)

ZEND_BEGIN_MODULE_GLOBALS(lightningcss)
zend_long max_input_bytes;
ZEND_END_MODULE_GLOBALS(lightningcss)

#ifdef ZTS
#define LIGHTNINGCSS_G(v) ZEND_TSRMG(lightningcss_globals_id, zend_lightningcss_globals *, v)
extern int lightningcss_globals_id;
#else
#define LIGHTNINGCSS_G(v) lightningcss_globals.v
extern zend_lightningcss_globals lightningcss_globals;
#endif

/* Registers the Lightningcss\Exception class; returns NULL on failure. */
zend_class_entry *lightningcss_register_exception_class(void);

#endif /* LIGHTNINGCSS_INTERNAL_H */
