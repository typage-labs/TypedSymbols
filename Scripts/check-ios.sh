#!/bin/bash
set -euo pipefail

# Compile only; no signing, device, or running simulator required.
# Extra arguments are forwarded to SwiftPM (for example --disable-sandbox).
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
# Current Xcode/SwiftPM raises package builds to its supported deployment floor.
# Validate the declared iOS 13 minimum separately with the compiler below.
target="arm64-apple-ios${IOS_DEPLOYMENT_TARGET:-15.0}"
options=(--scratch-path "$root/.build/ios" --triple "$target" --sdk "$sdk")
swift build "$@" "${options[@]}" --target TypedSymbols -Xswiftc -warnings-as-errors
bin_path="$(swift build "$@" "${options[@]}" --show-bin-path)"
module_path="$bin_path"
if [[ -d "$bin_path/Modules" ]]; then module_path="$bin_path/Modules"; fi
swiftc -typecheck -swift-version 5 -warnings-as-errors -sdk "$sdk" -target "$target" \
    -module-cache-path "$root/.build/ModuleCache" -I "$module_path" \
    Tests/Compilation/Valid.swift
echo "iOS package and SwiftUI consumer compilation passed ($target)."

temp="$(mktemp -d "${TMPDIR:-/tmp}/TypedSymbols-ios13.XXXXXX")"
trap 'rm -rf "$temp"' EXIT
module_cache="${CLANG_MODULE_CACHE_PATH:-$root/.build/IOS13ModuleCache}"
mkdir -p "$module_cache"
compiler=(swiftc -swift-version 5 -warnings-as-errors -sdk "$sdk"
    -target arm64-apple-ios13.0 -module-cache-path "$module_cache" -I "$temp")
"${compiler[@]}" -emit-module -parse-as-library -module-name TypedSymbols \
    -emit-module-path "$temp/TypedSymbols.swiftmodule" \
    Sources/TypedSymbols/Symbol.swift Sources/TypedSymbols/SwiftUI.swift \
    Sources/TypedSymbols/Generated/SymbolCatalog.swift
compiler+=(-typecheck)

# Positive control: the real module and SwiftUI must import at the declared floor.
"${compiler[@]}" Tests/Compilation/Valid.swift

failures=0
expect_failure() {
    local fixture="$1" diagnostic="$2"
    if "${compiler[@]}" "Tests/Compilation/$fixture.swift" >"$temp/diagnostics" 2>&1; then
        echo "FAIL: $fixture unexpectedly compiled for iOS 13" >&2
        failures=$((failures + 1))
        return
    fi
    if ! /usr/bin/grep -Eq "$diagnostic" "$temp/diagnostics"; then
        cat "$temp/diagnostics" >&2
        echo "FAIL: $fixture failed for an unexpected reason on iOS 13" >&2
        failures=$((failures + 1))
        return
    fi
    echo "PASS: $fixture rejected as expected on iOS 13"
}

expect_failure UnavailableSymbol "only available in iOS 15"
expect_failure UnavailableParent "only available in iOS 15"
expect_failure UnavailableAlias "'clock_badge_checkmark' is only available in iOS 15"
expect_failure InvalidUnnecessaryAlias "has no member 'bell_circle'"
if [[ "$failures" -ne 0 ]]; then exit 1; fi
echo "Direct iOS 13 module, SwiftUI consumer, and availability checks passed."
