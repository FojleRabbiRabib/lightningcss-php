/*
 * lightningcss-php — module lifecycle, INI entries, and phpinfo().
 * Copyright 2026 Fojle Rabbi (Rabib)
 * SPDX-License-Identifier: Apache-2.0
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "php.h"
#include "ext/standard/info.h"
#include "php_lightningcss.h"
#include "lightningcss_internal.h"
#include "lightningcss_arginfo.h"
#include "lightningcss_php_shim.h"

#if defined(ZTS) && defined(COMPILE_DL_LIGHTNINGCSS)
ZEND_TSRMLS_CACHE_DEFINE()
#endif

ZEND_DECLARE_MODULE_GLOBALS(lightningcss)

static PHP_GINIT_FUNCTION(lightningcss)
{
#if defined(COMPILE_DL_LIGHTNINGCSS) && defined(ZTS)
	ZEND_TSRMLS_CACHE_UPDATE();
#endif
	lightningcss_globals->max_input_bytes = LIGHTNINGCSS_DEFAULT_MAX_INPUT_BYTES;
}

PHP_INI_BEGIN()
STD_PHP_INI_ENTRY(LIGHTNINGCSS_INI_MAX_INPUT_BYTES, "16777216", PHP_INI_ALL, OnUpdateLong,
				  max_input_bytes, zend_lightningcss_globals, lightningcss_globals)
PHP_INI_END()

PHP_MINIT_FUNCTION(lightningcss)
{
	(void)type;
	(void)module_number;

	REGISTER_INI_ENTRIES();

	if (lightningcss_register_exception_class() == NULL) {
		return FAILURE;
	}

	return SUCCESS;
}

PHP_MSHUTDOWN_FUNCTION(lightningcss)
{
	(void)type;
	(void)module_number;

	UNREGISTER_INI_ENTRIES();

	return SUCCESS;
}

PHP_MINFO_FUNCTION(lightningcss)
{
	(void)zend_module;

	php_info_print_table_start();
	php_info_print_table_header(2, "lightningcss support", "enabled");
	php_info_print_table_row(2, "version", PHP_LIGHTNINGCSS_VERSION);
	php_info_print_table_row(2, "upstream pin", PHP_LIGHTNINGCSS_UPSTREAM_PIN);
	php_info_print_table_row(2, "shim version", lightningcss_php_shim_version());
	php_info_print_table_end();

	DISPLAY_INI_ENTRIES();
}

zend_module_entry lightningcss_module_entry = {
	STANDARD_MODULE_HEADER,
	"lightningcss",				 /* ext name                              */
	NULL,						 /* functions — none until first feature  */
	PHP_MINIT(lightningcss),	 /* MINIT                                 */
	PHP_MSHUTDOWN(lightningcss), /* MSHUTDOWN                             */
	NULL,						 /* RINIT                                 */
	NULL,						 /* RSHUTDOWN                             */
	PHP_MINFO(lightningcss),	 /* MINFO                                 */
	PHP_LIGHTNINGCSS_VERSION,	 /* version                               */
	PHP_MODULE_GLOBALS(lightningcss),
	PHP_GINIT(lightningcss),
	NULL, /* GSHUTDOWN                             */
	NULL, /* post deactivate                       */
	STANDARD_MODULE_PROPERTIES_EX};

#ifdef COMPILE_DL_LIGHTNINGCSS
ZEND_GET_MODULE(lightningcss)
#endif
