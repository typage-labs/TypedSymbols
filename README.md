# TypedSymbols

SF Symbols as statically checked Swift paths, with Xcode completion at each step.

Before:

```swift
Image(systemName: "bell.circle.fill")
```

After:

```swift
import SwiftUI
import TypedSymbols

Image(symbol: .bell.circle.fill)
Label("Notifications", symbol: .bell.fill)
```

TypedSymbols makes misspellings compiler errors and lets you discover the next
component through completion. It is an independent, minimal implementation of an
established idea: projects such as SFSafeSymbols and LuckeyLogic/SFSymbol also
provide typed access to SF Symbols. This package focuses on a generated hierarchy,
without dependencies, macros, dynamic member lookup, or runtime fallbacks.

## Installation

Requires a Swift 5.9-compatible toolchain, iOS 13+, or macOS 11+. `Label` requires
iOS 14+. Individual symbols can require newer OS versions.

Version 0.1.0 is being prepared for
[typage-labs/TypedSymbols](https://github.com/typage-labs/TypedSymbols). After the
`0.1.0` tag is published, add the repository in Xcode or use Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/typage-labs/TypedSymbols", from: "0.1.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [.product(name: "TypedSymbols", package: "TypedSymbols")]
    )
]
```

Before publication, add this checkout as a local package in Xcode or use
`.package(path: "../TypedSymbols")`.

The generated Swift catalogue is included. Once the package sources are available,
compilation does **not** need the SF Symbols app, the generator, network access,
or a build plugin.

## Paths and values

```swift
Symbol.bell.name                    // "bell"
Symbol.bell.fill.name               // "bell.fill"
Symbol.bell.circle.name             // "bell.circle"
Symbol.bell.circle.fill.name        // "bell.circle.fill"
Symbol.lock.shield.fill.name        // "lock.shield.fill"

if #available(iOS 15.0, macOS 12.0, *) {
    print(Symbol.arrow.down.to.line.circle.name)
}
```

Every child property comes from an exact dot-separated name in the source
catalogue. Components are not interpreted as semantic variants.

```swift
// These do not compile:
Symbol.bell.circle.square          // No such child.
Symbol.arrow.name                  // "arrow" is a navigation prefix, not a symbol.
Image(symbol: Symbol.arrow)        // A prefix is not a SymbolValue.
Symbol(name: "invented.symbol")    // No public raw-string initializer.
```

Actual symbols conform to `SymbolValue`, which provides `name`, `Hashable`, and
`Sendable`. Branch symbols have distinct generated value types; terminal leaves
share the lightweight `Symbol` struct. Use the common struct for heterogeneous
storage, or accept `SymbolValue` generically:

```swift
let favorites: [Symbol] = [Symbol(.bell), Symbol(.bell.circle.fill)]
let unique = Set(favorites)

func systemName<S: SymbolValue>(of symbol: S) -> String { symbol.name }
let name = systemName(of: .lock.shield.fill)
```

`Image(symbol:)` and `Label(_:symbol:)` forward to SwiftUI's system-image
initializers. Label supports both `LocalizedStringKey` and `StringProtocol`,
preserving SwiftUI's distinction between localized literals and string values.
Existing SwiftUI initializers remain available.

### Identifier spelling

Most components retain their official spelling. Numeric components gain an
underscore: `Symbol._0.circle.name == "0.circle"`. Swift keywords are escaped in
generated declarations, so `Symbol.repeat` works.

For a deterministic, collision-free mapping, components starting with an
underscore, components containing non-ASCII-identifier characters, and reserved
API names use `_u` followed by lowercase hexadecimal UTF-8 bytes. For example,
`name` maps to `_u6e616d65`; `_0` maps to `_u5f30`, distinct from numeric `0`.
The reserved set is defined beside the encoder in `SwiftCatalogGenerator.swift`.
These encodings change Swift spelling only, never the underlying symbol name.

## Availability

Generated properties and branch types carry `@available(iOS ..., macOS ..., *)` annotations
using the exact name's introduction metadata. The generator reads the explicit
release-to-OS-version table; it never derives versions from years. The macOS
minimum is clamped to 11.0, where native system-symbol image APIs are available,
even though the metadata lists 10.15 for some early names.

Hierarchical availability is deliberately **conservative along a path**. A branch may itself
be a newer symbol than one of its children: `asterisk` was introduced in iOS 15 /
macOS 12, while `asterisk.circle` was introduced in iOS 13. Because the branch is
also directly usable as a symbol, TypedSymbols requires iOS 15 / macOS 12 for both
expressions. Each generated path uses the maximum introduction versions of its
valid symbol ancestors and itself. Navigation-only prefixes have no symbol value.

This keeps every generated value safe to pass to a generic SwiftUI initializer
using ordinary availability checking, including Swift 5 language mode. Separating
navigation from availability-gated protocol conformance would complicate the API
and is not consistently enforced as an error in older Swift language modes.

### Compatibility aliases

When a valid ancestor makes a hierarchical path require a newer OS than its exact
symbol name, the generator adds a direct alias on `Symbol`:

```swift
// Hierarchical API: iOS 15+ / macOS 12+.
if #available(iOS 15.0, macOS 12.0, *) {
    print(Symbol.asterisk.circle.name) // "asterisk.circle"
}

// Direct alias: iOS 13+ / macOS 11+.
let symbol = Symbol.asterisk_circle
print(symbol.name)                    // "asterisk.circle"
Image(symbol: .asterisk_circle)
```

The alias returns the same exact name as the hierarchical expression and remains
a `Hashable`, `Sendable` `Symbol`. Its availability is the symbol's own introduction
version on each platform, clamped independently to the package minimums of iOS 13
and macOS 11. A later iOS version never increases its macOS requirement, or vice
versa. An alias is generated only when at least one of those platform requirements
would otherwise be raised by the hierarchy. Existing hierarchical paths and their
annotations are preserved; unaffected symbols do not gain a flat alias.

This catalogue generates **405 compatibility aliases**, with **no collisions**
against existing root properties or other aliases. They cover all symbols affected
by an ancestor's later availability: 394 on both platforms and 11 on iOS alone.

Alias names join individually encoded components with underscores. Root properties
and all natural alias spellings are reserved before resolving collisions. A
conflicting alias gains `_u` followed by the hexadecimal UTF-8 bytes of its complete
official name; suffixes `_2`, `_3`, and so on resolve any remaining conflict. Resolution is
deterministic and never replaces an existing root property. These are additional
Swift accessors, not additional SF Symbol names or runtime substitutions.

Use `if #available` or annotate the enclosing declaration when needed. There is no
automatic substitution or fallback. The metadata describes name introduction,
not availability of rendering modes, variable colors, animations, or localized
artwork. It does not encode removal/deprecation guarantees. Always test the visual
result on the OS versions your app supports.

## Catalogue provenance and regeneration

The included catalogue was generated from the locally installed **SF Symbols
27.0 (build 140)**. It contains **9,524 exact names**: **8,526 current names** and
**998 historical names** still present in the availability table, including
localized variants. The compatibility accessors do not increase this name count. All 9,524
were recognized by `NSImage(systemSymbolName:accessibilityDescription:)` on the
development machine running macOS 27. This is a check on that OS, not a guarantee
about every past OS release.

The source plist's SHA-256 was
`aa64472afbc0ba35b379a7ee4d68ce1d928e8f0ce5f8a7984cdf4d20653185c3`.

The generator reads a binary or XML `name_availability.plist` with this schema:

```text
symbols: [exactSymbolName: releaseIdentifier]
year_to_release: [releaseIdentifier: [platformName: versionString]]
```

On the inspected installation, the application and system availability tables are
identical after decoding. The system's `symbol_order.plist` lists the 8,526 current
names; the other 998 are exactly the availability-listed keys of
`name_aliases.strings`, mapping to 922 distinct current names. This count describes
names, not distinct drawings. The alias tables also contain old spellings and
internal-looking identifiers without availability, so they are not generation
inputs. The separate `legacy_aliases.strings` table is not a substitute for the
availability table. The app's search CLI groups some localized variants; its output is
not an exhaustive replacement. `layerset_availability.plist` concerns rendering
modes and is outside this package's scope.

From the package directory:

```sh
swift run GenerateSymbols
```

Discovery checks these paths in order:

1. `/Applications/SF Symbols.app/Contents/Resources/Metadata/name_availability.plist`
2. `/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist`

For reproducible regeneration, select a specific local installation explicitly:

```sh
swift run GenerateSymbols \
  --input "/Applications/SF Symbols.app/Contents/Resources/Metadata/name_availability.plist" \
  --output Sources/TypedSymbols/Generated/SymbolCatalog.swift

swift run GenerateSymbols --check
swift test
bash Scripts/check-compilation.sh
bash Scripts/check-ios.sh
```

Keep the SF Symbols version and input digest with your release notes. Updating
the app or switching to the system table may change the generated catalogue.
Output is sorted, contains no timestamp or machine-specific path, and is written
atomically after validation. `--check` checks the selected local source against
the output without modifying it. Exact duplicates are deduplicated; conflicting
availability, unknown releases, malformed names, and invalid versions fail.
Canonically equivalent Unicode path components with different UTF-8 spellings
are rejected instead of silently merging or changing an exact name.
Apple's resource paths and schema are implementation details, not a stable public
API. If they change, the generator fails instead of guessing; the included
catalogue continues to compile.

Do not hand-edit the generated catalogue. No Apple plist is checked in. Generator
tests construct small synthetic catalogues in Swift and can run independently of
any installed Apple metadata.

## Design and limits

The generated trie has one small struct per branching path; only valid symbols
conform to `SymbolValue`. All leaves reuse `Symbol`, reducing repeated types.
Child properties belong to their branches, not a flat list of unrelated variants.
Root members live in a constrained protocol extension, which enables generic
leading-dot lookup through [Swift SE-0299](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0299-extend-generic-static-member-lookup.md).

A flat enum is smaller but loses hierarchical completion. A struct for every leaf
adds unnecessary declarations. A generic phantom-path model still needs generated
marker types and constrained child extensions, increasing boilerplate here.
The selected representation has no runtime tree, lookup, or string concatenation.

- Thousands of generated declarations increase compile time and index size. The
  generated catalogue, rather than the handwritten library, accounts for most of
  the source size.
- Generated branch type names are implementation details. Prefer inferred types,
  generic `SymbolValue`, or stored `Symbol`: adding a child can turn a former leaf
  into a branch in a future catalogue.
- `SymbolValue` is a public interoperability protocol. Swift protocols cannot be
  sealed; a consumer can deliberately implement a custom conformer. The static
  guarantee applies to **generated paths**, not arbitrary third-party conformances.
- Only iOS and macOS availability is modeled. Other Apple platforms are outside
  the supported scope of this version.
- There are no custom symbol catalogues, fallbacks, macros, per-symbol generated
  documentation, or graphics in this package.

## Validation

```sh
swift test
bash Scripts/check-compilation.sh
bash Scripts/check-ios.sh
```

The XCTest suites cover names, intermediate and terminal values, SwiftUI overloads,
determinism, identifier collisions, duplicate handling, invalid input, and version
propagation, including native availability and complete compatibility-alias
coverage. The separate compiler checks import the library as an external
consumer, first compile valid examples, then require errors for nonexistent paths,
navigation-only prefixes, raw-string construction, unnecessary aliases, and
symbols used before their introduction. They
check diagnostics so an unrelated missing-module error cannot produce a false pass.

For 0.1.0, validation passed **29 XCTest tests**, **9 macOS and 4 iOS negative
compilation cases**, Debug and Release builds, and deterministic regeneration.
Compiler checks verified the macOS 11 and iOS 13 minimums. A consumer resolved
the `0.1.0` tag through a local Git URL, then built and ran name assertions and
SwiftUI value construction on macOS. Test, compiler-fixture, and Debug/Release
build checks used warnings as errors; the validation logs contained no compiler
warnings. The GitHub URL itself has not been tested before publication.

See the [0.1.0 release notes](RELEASE_NOTES.md) for measured build times, the exact
validation method, and remaining limits. The manifest targets Swift 5.9; a newer compiler in
Swift 5 language mode does not establish compatibility with an actual Swift 5.9
toolchain. SDK compilation is also distinct from running an app on a device or
simulator. Compiler fixtures build a separate macOS 11 module so SwiftPM's own
deployment-target floor cannot mask availability errors.

With the installed SDK, the SwiftPM iOS build targets iOS 15. The script also uses
the Swift compiler directly to build and import the library at the declared
**iOS 13 minimum**, checking valid SwiftUI expressions and expected availability
errors. This verifies the minimum at compile time; it does not replace execution
on an older OS. Set `IOS_DEPLOYMENT_TARGET` to choose the SwiftPM build's target
with a supporting SDK.

## License and Apple resources

The original package implementation is available under the [MIT license](LICENSE).
SF Symbols and Apple materials remain subject to Apple's terms. This package
contains generated Swift identifiers and OS introduction versions, not the SF
Symbols app, fonts, image files, exported SVGs, asset catalogues, or original plists.
The generator neither downloads nor redistributes those resources.

Consult the [Xcode and Apple SDKs Agreement](https://www.apple.com/legal/sla/docs/xcode.pdf)
and [Apple's SF Symbols guidelines](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)
for restrictions on Apple software and symbol artwork. Those sources do not give
an explicit standalone redistribution grant for the metadata database; this
project does not claim such a grant or relicense Apple's materials. Symbol-specific
usage restrictions still apply to images rendered by your app.
