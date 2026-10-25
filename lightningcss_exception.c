/*
 * lightningcss-php — the exception type every failure the extension raises
 * inherits from. Status codes land here as class constants together with the
 * shim mapping that raises them.
 * Copyright 2026 Fojle Rabbi (Rabib)
 * SPDX-License-Identifier: Apache-2.0
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "php.h"
#include "ext/spl/spl_exceptions.h"
#include "lightningcss_internal.h"

zend_class_entry *lightningcss_ce_exception;

zend_class_entry *lightningcss_register_exception_class(void)
{
	zend_class_entry ce;

	INIT_NS_CLASS_ENTRY(ce, "Lightningcss", "Exception", NULL);
	lightningcss_ce_exception = zend_register_internal_class_ex(&ce, spl_ce_RuntimeException);

	return lightningcss_ce_exception;
}
