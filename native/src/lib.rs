//! lightningcss-php — C-ABI shim between the PHP extension and the vendored
//! Lightning CSS engine.
//!
//! Copyright 2026 Fojle Rabbi (Rabib)
//! SPDX-License-Identifier: Apache-2.0
//!
//! FFI rules binding every export this crate will ever add: inputs arrive as
//! pointer + length from the C side and are treated as untrusted; no `unwrap`
//! or `expect` anywhere; every future engine call wraps `catch_unwind` — a
//! panic crossing the FFI boundary is undefined behaviour, never an option;
//! failures return status codes with caller-owned out-parameters, never
//! abort. UTF-8 is validated with the checked converter (NOT_UTF8 status),
//! never `from_utf8_unchecked`. All heap memory returned to C is Rust-owned
//! and freed only through this crate's exported free functions — C never
//! calls free() on it.
//!
//! The exports are the C ABI: they are called from C, never from Rust, and
//! every pointer dereference inside is validated before use.
#![deny(clippy::unwrap_used, clippy::expect_used)]
#![allow(clippy::not_unsafe_ptr_arg_deref)]

use std::collections::HashMap;
use std::ffi::CString;
use std::os::raw::c_char;
use std::panic::catch_unwind;
use std::ptr;
use std::slice;
use std::str;
use std::sync::{Arc, Mutex, RwLock};

use lightningcss::stylesheet::{
    MinifyOptions, ParserFlags, ParserOptions, PrinterOptions, StyleSheet,
};
use lightningcss::targets::{Browsers, Targets};

/// Status codes, mirroring the `Lightningcss\Exception` class constants and
/// the module's C-side macros. 0 is success; the rest map 1:1 onto the
/// exception constants. `TOO_LARGE` and `ALLOCATION_FAILED` are part of the
/// stable ABI but have no raising site in this scope: the input ceiling is
/// enforced C-side before the shim runs, and the engine aborts on true
/// allocation failure rather than reporting one.
const LIGHTNINGCSS_PHP_OK: i32 = 0;
const LIGHTNINGCSS_PHP_NOT_UTF8: i32 = 1;
#[allow(dead_code)]
const LIGHTNINGCSS_PHP_TOO_LARGE: i32 = 2;
const LIGHTNINGCSS_PHP_PARSE_FAILED: i32 = 3;
const LIGHTNINGCSS_PHP_INVALID_TARGETS: i32 = 4;
#[allow(dead_code)]
const LIGHTNINGCSS_PHP_ALLOCATION_FAILED: i32 = 5;
const LIGHTNINGCSS_PHP_INTERNAL: i32 = 6;

/// The targets cache holds successful resolutions only and is cleared whole
/// at this size — a deterministic bound against userland flooding the cache
/// with distinct query lists.
const TARGETS_CACHE_CAPACITY: usize = 64;

/// A byte range owned by the C side: a pointer and explicit length, never
/// assumed NUL-terminated. Zend string buffers map onto this directly.
#[repr(C)]
pub struct LightningcssPhpStr {
    pub ptr: *const c_char,
    pub len: usize,
}

impl LightningcssPhpStr {
    /// The bytes as a `&str`, or NOT_UTF8 with a sanitized message when the
    /// bytes are not valid UTF-8.
    fn as_str(&self, what: &str) -> Result<&str, (i32, String)> {
        if self.ptr.is_null() && self.len == 0 {
            return Ok("");
        }
        if self.ptr.is_null() {
            return Err((
                LIGHTNINGCSS_PHP_INTERNAL,
                format!("{what} is a null pointer with non-zero length"),
            ));
        }
        let bytes = unsafe { slice::from_raw_parts(self.ptr.cast::<u8>(), self.len) };
        str::from_utf8(bytes).map_err(|_| {
            (
                LIGHTNINGCSS_PHP_NOT_UTF8,
                format!("the {what} is not valid UTF-8"),
            )
        })
    }
}

/// One transform request. Every string is a `LightningcssPhpStr`; every flag
/// is a 0/1 int so the struct is portable across C compilers.
#[repr(C)]
pub struct LightningcssPhpTransformInput {
    pub code: LightningcssPhpStr,
    pub filename: LightningcssPhpStr,
    pub minify: i32,
    pub error_recovery: i32,
    pub custom_media: i32,
    pub scroll_navigation_controls: i32,
    pub queries: *const LightningcssPhpStr,
    pub queries_len: u32,
}

/// One transform outcome. `code` is a boxed byte slice (it may contain any
/// bytes and is not NUL-terminated); each warning is a NUL-terminated
/// C string. All memory is Rust-owned: the caller releases the whole struct
/// with `lightningcss_php_transform_output_free` and standalone error
/// strings with `lightningcss_php_string_free`.
#[repr(C)]
pub struct LightningcssPhpTransformOutput {
    pub code: *mut c_char,
    pub code_len: usize,
    pub warnings: *mut *mut c_char,
    pub warnings_len: usize,
}

/// Engine state shared across calls: query-list resolutions (successful and
/// empty alike). A contended or poisoned lock falls back to uncached
/// resolution — a forked child must never inherit a held mutex, and no
/// engine call ever waits on user-controlled state.
static TARGETS_CACHE: Mutex<Option<HashMap<String, Option<Browsers>>>> = Mutex::new(None);

/// Resolves a query list through the cache, or upstream on a miss. An empty
/// list resolves to no browsers, matching the CLI's empty `--targets`.
fn resolve_targets(queries: &[String]) -> Result<Option<Browsers>, (i32, String)> {
    if queries.is_empty() {
        return Ok(None);
    }

    // Debug formatting is an injective key: it escapes newlines, quotes and
    // NUL, so two different query lists can never collide the way a plain
    // join would (upstream rejects a list holding an empty query; a joined
    // key would hide that behind a previous hit).
    let key = format!("{queries:?}");

    if let Ok(guard) = TARGETS_CACHE.try_lock() {
        if let Some(browsers) = guard.as_ref().and_then(|cache| cache.get(&key)) {
            return Ok(*browsers);
        }
    }

    let resolved = Browsers::from_browserslist(queries)
        .map_err(|err| (LIGHTNINGCSS_PHP_INVALID_TARGETS, err.to_string()))?;

    if let Ok(mut guard) = TARGETS_CACHE.try_lock() {
        let cache = guard.get_or_insert_with(HashMap::new);
        if cache.len() >= TARGETS_CACHE_CAPACITY {
            cache.clear();
        }
        cache.insert(key, resolved);
    }

    Ok(resolved)
}

/// A resolved outcome of the transform pipeline, still owning its buffers.
struct TransformOutcome {
    code: Vec<u8>,
    warnings: Vec<CString>,
}

/// The parse → minify → print pipeline, mirroring the CLI's own wiring
/// (flags from `main.rs`, warnings collected only in error-recovery mode,
/// targets resolved once and shared by minify and print).
fn transform_pipeline(
    input: &LightningcssPhpTransformInput,
) -> Result<TransformOutcome, (i32, String)> {
    let code = input.code.as_str("stylesheet")?;
    let filename = input.filename.as_str("filename")?;
    if !matches!(input.minify, 0 | 1)
        || !matches!(input.error_recovery, 0 | 1)
        || !matches!(input.custom_media, 0 | 1)
        || !matches!(input.scroll_navigation_controls, 0 | 1)
    {
        return Err((
            LIGHTNINGCSS_PHP_INTERNAL,
            "malformed transform input flags".into(),
        ));
    }

    let mut queries: Vec<String> = Vec::new();
    if input.queries_len > 0 {
        if input.queries.is_null() {
            return Err((
                LIGHTNINGCSS_PHP_INTERNAL,
                "queries is a null pointer with non-zero length".into(),
            ));
        }
        let raw = unsafe { slice::from_raw_parts(input.queries, input.queries_len as usize) };
        for query in raw {
            queries.push(query.as_str("browserslist query")?.to_owned());
        }
    }
    let browsers = resolve_targets(&queries)?;

    let mut flags = ParserFlags::empty();
    flags.set(ParserFlags::CUSTOM_MEDIA, input.custom_media != 0);
    flags.set(
        ParserFlags::SCROLL_NAVIGATION_CONTROLS,
        input.scroll_navigation_controls != 0,
    );

    let warnings_cell = (input.error_recovery != 0).then(|| Arc::new(RwLock::new(Vec::new())));

    let options = ParserOptions {
        filename: filename.to_owned(),
        flags,
        error_recovery: input.error_recovery != 0,
        warnings: warnings_cell.clone(),
        ..ParserOptions::default()
    };

    let mut stylesheet = StyleSheet::parse(code, options)
        .map_err(|err| (LIGHTNINGCSS_PHP_PARSE_FAILED, err.to_string()))?;

    let targets = Targets::from(browsers);
    stylesheet
        .minify(MinifyOptions {
            targets,
            ..MinifyOptions::default()
        })
        .map_err(|err| (LIGHTNINGCSS_PHP_PARSE_FAILED, err.to_string()))?;

    let result = stylesheet
        .to_css(PrinterOptions {
            minify: input.minify != 0,
            targets,
            ..PrinterOptions::default()
        })
        .map_err(|err| (LIGHTNINGCSS_PHP_PARSE_FAILED, err.to_string()))?;

    let warnings = match warnings_cell {
        Some(cell) => match cell.read() {
            Ok(guard) => guard
                .iter()
                .map(|warning| engine_string(&warning.to_string()))
                .collect::<Result<Vec<CString>, (i32, String)>>()?,
            Err(_) => Vec::new(),
        },
        None => Vec::new(),
    };

    Ok(TransformOutcome {
        code: result.code.into_bytes(),
        warnings,
    })
}

/// Converts an engine message into a C string, replacing interior NUL bytes
/// (the engine's messages are text, but they are untrusted input to this
/// conversion).
fn engine_string(message: &str) -> Result<CString, (i32, String)> {
    CString::new(message.replace('\0', "\u{FFFD}"))
        .map_err(|_| (LIGHTNINGCSS_PHP_INTERNAL, "unencodable message".into()))
}

/// Writes a sanitized message into the caller's error out-parameter.
fn set_error_message(out: *mut *mut c_char, message: &str) {
    if out.is_null() {
        return;
    }
    if let Ok(text) = engine_string(message) {
        unsafe { *out = text.into_raw() };
    }
}

/// Runs one transform. Returns `LIGHTNINGCSS_PHP_OK` (0) with `out` filled,
/// or a non-zero status with `*error_message` a Rust-owned C string. On
/// success the caller must free `out` with
/// `lightningcss_php_transform_output_free`; on failure it may free
/// `*error_message` with `lightningcss_php_string_free`. Both out-parameters
/// are written last; a NULL `input` or `out` is a caller contract violation
/// reported as INTERNAL, never a panic.
///
/// # Safety
/// `input` must point to a valid, fully initialized
/// `LightningcssPhpTransformInput` whose string pointers reference `len`
/// readable bytes; `out` must point to a zero-initialized output struct.
#[no_mangle]
pub extern "C" fn lightningcss_php_transform(
    input: *const LightningcssPhpTransformInput,
    out: *mut LightningcssPhpTransformOutput,
    error_message: *mut *mut c_char,
) -> i32 {
    let run = || {
        // Contract checks first: every allocation below must be reachable
        // only with both out-parameters valid, so no error path after this
        // point has anything to clean up by hand.
        let input = match unsafe { input.as_ref() } {
            Some(input) => input,
            None => return Err((LIGHTNINGCSS_PHP_INTERNAL, "transform input is null".into())),
        };
        let out = match unsafe { out.as_mut() } {
            Some(out) => out,
            None => return Err((LIGHTNINGCSS_PHP_INTERNAL, "transform output is null".into())),
        };
        let outcome = transform_pipeline(input)?;

        // Transfer ownership: into_raw (never as_ptr — the C side frees
        // these through the exported free functions).
        let warnings: Vec<*mut c_char> = outcome
            .warnings
            .into_iter()
            .map(|warning| warning.into_raw())
            .collect();

        let code = outcome.code.into_boxed_slice();
        let code_len = code.len();
        let code_ptr = Box::into_raw(code) as *mut c_char;

        let warning_ptrs: Box<[*mut c_char]> = warnings.into_boxed_slice();
        let warnings_len = warning_ptrs.len();
        let warnings_ptr = Box::into_raw(warning_ptrs) as *mut *mut c_char;

        out.code = code_ptr;
        out.code_len = code_len;
        out.warnings = warnings_ptr;
        out.warnings_len = warnings_len;
        Ok(())
    };

    match catch_unwind(run) {
        Ok(Ok(())) => LIGHTNINGCSS_PHP_OK,
        Ok(Err((status, message))) => {
            set_error_message(error_message, &message);
            status
        }
        Err(_) => {
            set_error_message(
                error_message,
                "an internal error occurred while processing the stylesheet",
            );
            LIGHTNINGCSS_PHP_INTERNAL
        }
    }
}

/// Releases an output struct previously filled by `lightningcss_php_transform`.
/// Zeroes the struct so a double free is a no-op rather than undefined
/// behaviour.
///
/// # Safety
/// `out` must be null or point to a struct filled by this crate and not yet
/// freed.
#[no_mangle]
pub extern "C" fn lightningcss_php_transform_output_free(out: *mut LightningcssPhpTransformOutput) {
    let out = match unsafe { out.as_mut() } {
        Some(out) => out,
        None => return,
    };

    if !out.code.is_null() {
        drop(unsafe {
            Box::from_raw(ptr::slice_from_raw_parts_mut(
                out.code.cast::<u8>(),
                out.code_len,
            ))
        });
        out.code = ptr::null_mut();
    }

    if !out.warnings.is_null() {
        let warning_ptrs = unsafe {
            Box::from_raw(ptr::slice_from_raw_parts_mut(
                out.warnings,
                out.warnings_len,
            ))
        };
        for warning in warning_ptrs.iter() {
            if !(*warning).is_null() {
                drop(unsafe { CString::from_raw(*warning) });
            }
        }
        out.warnings = ptr::null_mut();
        out.warnings_len = 0;
    }

    out.code_len = 0;
}

/// Releases an error string previously returned through an error
/// out-parameter.
///
/// # Safety
/// `ptr` must be null or a pointer returned by this crate for C-side free.
#[no_mangle]
pub extern "C" fn lightningcss_php_string_free(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(unsafe { CString::from_raw(ptr) });
    }
}

/// Returns the shim's own version string. Static storage: the pointer
/// outlives the call and is never freed.
#[no_mangle]
pub extern "C" fn lightningcss_php_shim_version() -> *const std::os::raw::c_char {
    concat!(env!("CARGO_PKG_VERSION"), "\0").as_ptr() as *const std::os::raw::c_char
}
