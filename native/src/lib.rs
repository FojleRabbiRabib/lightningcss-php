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
//! abort.
#![deny(clippy::unwrap_used, clippy::expect_used)]

/// Returns the shim's own version string. Static storage: the pointer
/// outlives the call and is never freed. This export proves the archive
/// links before the engine dependency lands.
#[no_mangle]
pub extern "C" fn lightningcss_php_shim_version() -> *const std::os::raw::c_char {
    concat!(env!("CARGO_PKG_VERSION"), "\0").as_ptr() as *const std::os::raw::c_char
}
