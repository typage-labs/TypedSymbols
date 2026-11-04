# Changelog

## 0.1.0 — 2026-11-04

Initial release prepared for publication; the remote tag and GitHub release are
not published yet.

### Added

- A statically generated hierarchy for 9,524 SF Symbol names from SF Symbols 27.0
  (build 140), including 8,526 current and 998 historical names.
- `Symbol` and `SymbolValue` with `Hashable` and `Sendable` conformance, exact name
  access, and no public raw-string initializer.
- SwiftUI `Image(symbol:)` and `Label(_:symbol:)` initializers.
- 405 generated compatibility aliases for symbols whose hierarchical path raises the
  introduction requirement above the symbol's native availability. Each alias
  preserves independent iOS and macOS availability and the exact symbol name.
- Deterministic alias collision handling that preserves existing root properties;
  no collisions occur in the included catalogue.
- A dependency-free Swift generator, regeneration checks, XCTest coverage, and
  compiler fixtures for valid and invalid expressions.

### Compatibility

- Swift tools version 5.9; iOS 13+ and macOS 11+.
- Hierarchical paths retain their existing availability annotations. Use a direct
  compatibility alias when an ancestor imposes a later OS requirement.
- No runtime fallback, macros, dynamic member lookup, or bundled Apple artwork.

Validation results and known limits are recorded in [the release notes](RELEASE_NOTES.md).
