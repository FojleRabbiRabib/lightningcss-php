/* This is a generated file, edit the .stub.php file instead.
 * Stub hash: 3cd3816725ea9046bc98e0e75a2198ceca613b04 */

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_Lightningcss_TransformOptions___construct, 0, 0, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, minify, _IS_BOOL, 0, "false")
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, targets, IS_ARRAY, 1, "null")
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, errorRecovery, _IS_BOOL, 0, "false")
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, customMedia, _IS_BOOL, 0, "false")
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, scrollNavigationControls, _IS_BOOL, 0, "false")
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, filename, IS_STRING, 0, "\'\'")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_Lightningcss_TransformResult___construct, 0, 0, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_OBJ_INFO_EX(arginfo_class_Lightningcss_Css_transform, 0, 1, Lightningcss\\TransformResult, 0)
	ZEND_ARG_TYPE_INFO(0, css, IS_STRING, 0)
	ZEND_ARG_OBJ_INFO_WITH_DEFAULT_VALUE(0, options, Lightningcss\\TransformOptions, 1, "null")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_Lightningcss_Css_version, 0, 0, IS_STRING, 0)
ZEND_END_ARG_INFO()
