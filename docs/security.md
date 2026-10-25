# Security

This document describes the security posture of lightningcss-php: the threat model it
defends against today, the invariants its implementation maintains, and how to report a
vulnerability.

## Threat model

The primary adversary is **untrusted CSS input**: a stylesheet arriving from an HTTP
upload, a third-party API, or user-generated content, parsed inside a php-fpm worker that
also serves other requests.

Defenses in place today:

- **Input-size ceiling.** `lightningcss.max_input_bytes` (default 16 MiB) bounds any
  input accepted by processing entry points, rejecting oversized payloads before work
  starts. This is the first-line defense against denial-of-service via decompression-style
  amplification and memory exhaustion.

Defenses that land together with the processing API (each documented here when present):

- **Dimensional and structural ceilings** on parse work (nesting depth, selector-list
  size, bundle fan-out).
- **Bundle path containment.** `@import`/`url()` resolution refuses targets outside the
  explicitly configured root; a bundle operation can never read arbitrary filesystem
  paths.
- **Source-map data hygiene.** Source-map contents are treated as untrusted data, never
  executed or resolved.

## Implementation invariants

- **No unbounded native allocation.** Every admission point checks a ceiling first and
  fails closed; allocation failures surface as PHP exceptions, never aborts.
- **Panics never cross the FFI boundary.** The Rust shim wraps engine calls in
  `catch_unwind`; a Rust panic cannot escape into C (undefined behaviour) — it becomes a
  sanitized PHP exception.
- **Symbol isolation.** The linker version script (`lightningcss.map`) exports only
  `get_module` from the `.so`; engine and shim internals are invisible to other
  extensions.
- **Sanitized error messages.** Exceptions never leak internal paths or raw native state.
- **ELF hardening.** Release artifacts are built with full RELRO, BIND_NOW, non-executable
  stack, no RPATH, and are verified by `tools/elf-gates.sh` on every build.

## What the skeleton does NOT do

- No filesystem access, no bundle resolution, no network I/O — these surfaces do not
  exist yet, so no attack surface exists through them.
- No dynamic code evaluation of input CSS.

## Reporting a vulnerability

Report privately via the repository's security advisory feature (GitHub
"Security" → "Report a vulnerability") rather than a public issue. Include the PHP
version, extension version (`php --ri lightningcss`), a minimal reproducing input, and the
observed versus expected behaviour. Please allow time for a fix before public disclosure.
