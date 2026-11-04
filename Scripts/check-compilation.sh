#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
if [[ "$(uname -s)" != Darwin ]]; then
    echo "Compilation fixtures require macOS and the Apple SDKs." >&2
    exit 1
fi

temp="$(mktemp -d "${TMPDIR:-/tmp}/TypedSymbols-compile.XXXXXX")"
trap 'rm -rf "$temp"' EXIT
module_cache="${CLANG_MODULE_CACHE_PATH:-$root/.build/CompilationModuleCache}"
mkdir -p "$module_cache"

compiler=(swiftc -swift-version 5 -warnings-as-errors -I "$temp"
    -module-cache-path "$module_cache"
    -target "$(uname -m)-apple-macosx11.0")

# Build an external-consumer module at the declared baseline. Recent SwiftPM/Xcode
# backends can raise package build deployment targets to their own SDK minimum.
"${compiler[@]}" -emit-module -parse-as-library -module-name TypedSymbols \
    -emit-module-path "$temp/TypedSymbols.swiftmodule" \
    Sources/TypedSymbols/Symbol.swift Sources/TypedSymbols/SwiftUI.swift \
    Sources/TypedSymbols/Generated/SymbolCatalog.swift
compiler+=(-typecheck)

# The positive control ensures a missing module/SDK cannot make negatives pass.
"${compiler[@]}" Tests/Compilation/Valid.swift

failures=0
expect_failure() {
    local fixture="$1" diagnostic="$2"
    if "${compiler[@]}" "Tests/Compilation/$fixture.swift" >"$temp/diagnostics" 2>&1; then
        echo "FAIL: $fixture unexpectedly compiled" >&2
        failures=$((failures + 1))
        return
    fi
    if ! /usr/bin/grep -Eq "$diagnostic" "$temp/diagnostics"; then
        cat "$temp/diagnostics" >&2
        echo "FAIL: $fixture failed for an unexpected reason" >&2
        failures=$((failures + 1))
        return
    fi
    echo "PASS: $fixture rejected as expected"
}

expect_failure InvalidPath "has no member 'square'|static member 'square' cannot be used"
expect_failure InvalidRoot "has no member 'typedSymbolsThisSymbolDoesNotExist'"
expect_failure InvalidPrefixName "has no member 'name'"
expect_failure InvalidPrefixImage "conform to 'SymbolValue'"
expect_failure InvalidRawInitializer "inaccessible|extraneous argument label|requires that.*conform"
expect_failure UnavailableSymbol "only available in macOS 12"
expect_failure UnavailableParent "only available in macOS 12"
expect_failure UnavailableAlias "'clock_badge_checkmark' is only available in macOS 12"
expect_failure InvalidUnnecessaryAlias "has no member 'bell_circle'"
if [[ "$failures" -ne 0 ]]; then exit 1; fi
echo "All compilation checks passed."
