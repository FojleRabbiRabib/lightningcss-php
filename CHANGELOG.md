# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Developer gates: PHPStan analyses `tests/` and `tools/` and activates from the first
  runtime PHP file (the stub is loaded via `scanFiles` only, shared `tools/phpstan.sh`
  entry point for composer and CI), and PHP_CodeSniffer scans the stub, `tests/`, and
  `tools/` under PSR-12 with two documented exceptions (`MultipleClasses`, `SideEffects`).
- The vendored Lightning CSS engine is linked: upstream pin 1.33.0 (crate 1.0.0-alpha.72)
  as a verified path dependency, the Rust MSRV floor rises from 1.75 to 1.89 (the locked
  dependency tree's own maximum), and source builds are fully offline via the vendored
  crate tree produced by `tools/fetch-lightningcss.sh` (`--locked --offline` everywhere).

### Added

- Repository scaffold: multi-ABI build (PHP 8.3/8.4/8.5), Rust shim crate skeleton,
  symbol-isolated linking, PIE package manifest, CI, installation docs, and the extension base
  surface (`Lightningcss\Exception`, `lightningcss.max_input_bytes`).
- The shim's transform C-ABI: `lightningcss_php_transform` (single-shot parse → minify →
  print with `catch_unwind` panic isolation, checked UTF-8 admission, sanitized status codes,
  and a bounded browserslist resolution cache) plus the matching free functions.
