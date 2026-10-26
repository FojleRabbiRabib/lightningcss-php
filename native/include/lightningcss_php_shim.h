/*
 * lightningcss-php — C-ABI surface of the Rust shim archive. Every
 * declaration here mirrors an export and a #[repr(C)] struct of
 * native/src/lib.rs; the extension side treats every input to these
 * functions as untrusted. All heap memory returned by the shim is
 * Rust-owned: release it only through lightningcss_php_transform_output_free
 * and lightningcss_php_string_free — never with free().
 * Copyright 2026 Fojle Rabbi (Rabib)
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef LIGHTNINGCSS_PHP_SHIM_H
#define LIGHTNINGCSS_PHP_SHIM_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Status codes, mirroring the Lightningcss\Exception class constants in
 * lightningcss.stub.php and their C-side registration. 0 is success.
 * LIGHTNINGCSS_PHP_TOO_LARGE and LIGHTNINGCSS_PHP_ALLOCATION_FAILED are part
 * of the stable ABI but have no raising site yet: the input ceiling is
 * enforced before the shim runs, and the engine aborts on true allocation
 * failure rather than reporting one.
 */
enum {
	LIGHTNINGCSS_PHP_OK = 0,
	LIGHTNINGCSS_PHP_NOT_UTF8 = 1,
	LIGHTNINGCSS_PHP_TOO_LARGE = 2,
	LIGHTNINGCSS_PHP_PARSE_FAILED = 3,
	LIGHTNINGCSS_PHP_INVALID_TARGETS = 4,
	LIGHTNINGCSS_PHP_ALLOCATION_FAILED = 5,
	LIGHTNINGCSS_PHP_INTERNAL = 6
};

/*
 * A byte range owned by the caller: a pointer and explicit length, never
 * assumed NUL-terminated. zend_string buffers map onto this directly.
 */
typedef struct {
	const char *ptr;
	size_t len;
} lightningcss_php_str;

/*
 * One transform request. Flags are 0/1 ints; queries is an array of
 * queries_len browserslist queries (NULL when queries_len is 0).
 */
typedef struct {
	lightningcss_php_str code;
	lightningcss_php_str filename;
	int32_t minify;
	int32_t error_recovery;
	int32_t custom_media;
	int32_t scroll_navigation_controls;
	const lightningcss_php_str *queries;
	uint32_t queries_len;
} lightningcss_php_transform_input;

/*
 * One transform outcome, owned by the shim until freed. code is a byte
 * buffer of code_len bytes (not NUL-terminated); warnings is an array of
 * warnings_len NUL-terminated C strings.
 */
typedef struct {
	char *code;
	size_t code_len;
	char **warnings;
	size_t warnings_len;
} lightningcss_php_transform_output;

/*
 * Runs one transform (parse, minify, print). Returns
 * LIGHTNINGCSS_PHP_OK with *out filled, or a non-zero status with
 * *error_message a shim-owned C string. On success the caller must free
 * *out with lightningcss_php_transform_output_free; on failure it may free
 * *error_message with lightningcss_php_string_free. Both out-parameters are
 * written last; on entry *out must be zero-initialized and *error_message
 * is only written on failure.
 */
int32_t lightningcss_php_transform(const lightningcss_php_transform_input *input,
								   lightningcss_php_transform_output *out, char **error_message);

/* Releases an output struct previously filled by the transform. The struct
 * is zeroed, so a double free is a no-op. */
void lightningcss_php_transform_output_free(lightningcss_php_transform_output *out);

/* Releases an error string previously returned through an error
 * out-parameter. NULL is a no-op. */
void lightningcss_php_string_free(char *ptr);

/* NUL-terminated shim version; static storage, never freed. */
const char *lightningcss_php_shim_version(void);

#ifdef __cplusplus
}
#endif

#endif /* LIGHTNINGCSS_PHP_SHIM_H */
