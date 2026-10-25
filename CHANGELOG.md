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

### Added

- Repository scaffold: multi-ABI build (PHP 8.3/8.4/8.5), Rust shim crate skeleton,
  symbol-isolated linking, PIE package manifest, CI, installation docs, and the extension base
  surface (`Lightningcss\Exception`, `lightningcss.max_input_bytes`).
