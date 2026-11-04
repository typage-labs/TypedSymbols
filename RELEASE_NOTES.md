# TypedSymbols 0.1.0

Prepared on 2026-11-04. Publication is pending explicit approval; no remote tag or
GitHub release is claimed by these notes.

TypedSymbols provides type-safe SF Symbols for Swift, with hierarchical dot
notation, compile-time validation, and OS availability annotations. It includes
SwiftUI `Image` and `Label` initializers and has no external dependencies.

## Compatibility aliases

The hierarchical API remains intact. For symbols whose parent paths require a
newer OS than the symbol itself, generated direct aliases expose the symbol at
its native availability:

```swift
// iOS 15+ / macOS 12+ through the hierarchy.
Symbol.asterisk.circle

// iOS 13+ / macOS 11+ through the direct alias.
Symbol.asterisk_circle
Image(symbol: .asterisk_circle)
```

Both expressions return `"asterisk.circle"` through `.name`. Direct aliases are
generated only for affected symbols. Their iOS and macOS versions are handled
independently and respect the package's minimum platform versions. They do not
perform runtime fallback or add symbol names to the catalogue.

Alias components use the existing identifier encoder and are joined with
underscores. All root names and natural alias names are reserved before conflict
resolution. A conflict appends `_u` and the full official name encoded as
hexadecimal UTF-8; suffixes `_2`, `_3`, and so on handle any remaining conflict. Existing
properties are never overwritten.

The generated catalogue contains **405 compatibility aliases**, with **zero root
collisions and zero alias-to-alias collisions**. They cover all affected names:
394 need the alias for both supported platforms and 11 for iOS only. The existing
9,524-name hierarchy is preserved byte-for-byte as the generated file's prefix;
the aliases are appended in a separate constrained root extension.

## Catalogue

- SF Symbols 27.0, build 140.
- 9,524 exact symbol names: 8,526 current names and 998 historical aliases from
  the availability table. The historical aliases map to 922 distinct current
  names; symbol-name counts are not artwork counts.
- Source: the locally installed `name_availability.plist`, decoded together with
  its explicit release-to-platform-version table.
- Source SHA-256:
  `aa64472afbc0ba35b379a7ee4d68ce1d928e8f0ce5f8a7984cdf4d20653185c3`.

The generated Swift catalogue is included in the package. Consumers do not need
SF Symbols installed or access to the generator's source metadata.

## Supported platforms

The package declares Swift tools version 5.9, iOS 13+, and macOS 11+.
`Label(_:symbol:)` requires iOS 14+. Each generated accessor carries its own
availability annotations. The macOS minimum is clamped to 11.0 because the source
metadata lists 10.15 for some early names while native system-symbol image APIs
require macOS 11.

## Validation

The following results come from executed checks for the prepared 0.1.0 sources.

Validation uses an Apple arm64 host, Swift 6.4 in Swift 5 language mode, and Xcode
27.1. Build timings are recorded separately from incremental test runs.

| Check | Result |
| --- | --- |
| XCTest suite | Passed: 29 tests (12 library/integration tests and 17 generator tests), with warnings treated as errors and no compiler warnings |
| macOS positive and negative compilation fixtures | Passed: a macOS 11 module and SwiftUI consumer, plus 9 negative cases checked for their expected diagnostics |
| iOS library and SwiftUI consumer compilation | Passed: SwiftPM build at iOS 15; direct compiler build/import at iOS 13 with valid SwiftUI expressions and 4 diagnostic-checked negative cases |
| Deterministic regeneration, `GenerateSymbols --check` | Passed for the complete generated catalogue, including compatibility aliases, with zero compiler warnings |
| Debug and Release builds, compiler warnings | Passed in separate clean build directories, with warnings treated as errors and zero compiler warnings |
| Full Release package, including the generator executable | Passed with `-debug-info-format none`; the default build's dSYM generation was blocked by the environment |
| Exhaustive catalogue and compatibility-alias audit | Passed: all 9,524 names preserved; exactly 405 required aliases; no missing or unnecessary aliases, collisions, or incorrect availability pairs |
| Git-based package consumer integration | Passed: resolved and freshly cloned tag `0.1.0` through a local bare Git URL, then compiled and ran a consumer with typed-name, alias-equality, and SwiftUI value-construction assertions; zero compiler warnings |
| Full-catalogue build timings | Debug: 29.8 seconds; Release: 55.9 seconds |

These are elapsed wall times for building the full `TypedSymbols` library target,
including the catalogue, on the validation host. Debug and Release ran serially
with four build jobs and distinct clean SwiftPM build directories. SDK and module
caches were shared and already warm. They are single-run build measurements, not
compiler-only timings or fully cold-cache benchmarks. The generated catalogue has
57,988 lines and 3,006,567 bytes (approximately 3.0 MB).

The Git consumer used a URL dependency and tagged version resolution, not a local
path dependency. It verifies that the package builds from a Git checkout without
developer-specific source paths. The actual GitHub network URL has not been tested:
that check remains dependent on repository access and the approved publication.

Both compiler-fixture scripts treat warnings as errors and produced no compiler
warnings. The macOS run emitted sandbox permission notices, but all compiler
assertions passed and the script completed successfully.

The default full-package Release build compiled and linked the generator, then
failed when `dsymutil` reported `Operation not permitted`. Repeating that build
with `-debug-info-format none` succeeded with zero compiler warnings. This flag
omits the debug-symbol artifact; it does not change the package's source or
disable compiler warnings. The clean Release library timing above was measured
with the default debug-information setting.

An actual Swift 5.9 toolchain and older operating systems have not been exercised.
SwiftPM's build with the installed SDK uses an iOS 15 target; the separate direct
compiler checks verify the declared iOS 13 minimum at compile time. CoreSimulator access is
unavailable in the development environment; no simulator or device run is claimed.
Xcode indexing time and interactive autocomplete responsiveness have not been
measured. Thousands of generated declarations can affect both.

## Metadata and licensing limits

Apple's resource locations and plist schema are implementation details. The data
describes name introduction, not removal guarantees or the introduction of every
rendering mode, animation, or localized drawing. Visual results must still be
tested on the operating systems an app supports.

The original package implementation is MIT licensed. The package distributes
generated Swift identifiers and introduction versions; it does not include
Apple's application, fonts, drawings, SVG exports, asset catalogues, or original
plists. No such resources are downloaded by the generator.

Apple materials remain subject to the
[Xcode and Apple SDKs Agreement](https://www.apple.com/legal/sla/docs/xcode.pdf)
and [SF Symbols guidelines](https://developer.apple.com/design/human-interface-guidelines/sf-symbols).
These sources do not provide an explicit standalone redistribution grant for the
metadata database. The package does not claim such a grant or relicense Apple
materials. Symbol-specific restrictions still apply to rendered artwork.

## Publication target

Repository: [typage-labs/TypedSymbols](https://github.com/typage-labs/TypedSymbols).
Tag and release name: `0.1.0`.

Publishing the repository, pushing code, creating a remote tag, or publishing the
release requires the requested explicit approval after the final preparation
report. These release notes do not imply that any of those operations occurred.
