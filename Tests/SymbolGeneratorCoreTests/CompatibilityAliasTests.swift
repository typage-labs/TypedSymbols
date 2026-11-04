import Foundation
import XCTest
@testable import SymbolGeneratorCore

final class CompatibilityAliasTests: XCTestCase {
    private func entry(_ name: String, _ iOS: String = "13.0", _ macOS: String = "11.0") throws -> CatalogEntry {
        try CatalogEntry(name: name, iOS: iOS, macOS: macOS)
    }

    func testAsteriskAliasRestoresNativeAvailabilityAndKeepsHierarchy() throws {
        let catalog = try Catalog(entries: [entry("asterisk", "15.0", "12.0"), entry("asterisk.circle", "13.0", "10.15")])
        let aliases = SwiftCatalogGenerator.compatibilityAliases(catalog: catalog)
        XCTAssertEqual(aliases.count, 1)
        XCTAssertEqual(aliases.first?.identifier, "asterisk_circle")
        XCTAssertEqual(aliases.first?.symbolName, "asterisk.circle")
        XCTAssertEqual(aliases.first?.iOS, try OSVersion("13.0"))
        XCTAssertEqual(aliases.first?.macOS, try OSVersion("11.0"))
        let source = SwiftCatalogGenerator.generate(catalog: catalog)
        XCTAssertTrue(source.contains("@available(iOS 13.0, macOS 11.0, *)\n    static var `asterisk_circle`: Symbol { .init(name: \"asterisk.circle\") }"))
        XCTAssertTrue(source.contains("@available(iOS 15.0, macOS 12.0, *)\n        public var `circle`: Symbol { .init(name: \"asterisk.circle\") }"))
    }

    func testNativePlatformVersionsAreComparedAndClampedIndependently() throws {
        let catalog = try Catalog(entries: [
            entry("ios", "17.0", "11.0"), entry("ios.child", "15.0", "14.0"),
            entry("mac", "13.0", "14.0"), entry("mac.child", "16.0", "12.0"),
            entry("floor", "13.0", "10.15.4"), entry("floor.child", "13.0", "10.15"),
            entry("same", "15.0", "12.0"), entry("same.child", "15.0", "12.0"),
            entry("later", "15.0", "12.0"), entry("later.child", "16.0", "13.0"),
            entry("namespace.leaf", "13.0", "11.0")
        ])
        let aliases = SwiftCatalogGenerator.compatibilityAliases(catalog: catalog)
        XCTAssertEqual(aliases.map(\.symbolName), ["ios.child", "mac.child"])
        XCTAssertEqual(aliases[0].iOS, try OSVersion("15.0"))
        XCTAssertEqual(aliases[0].macOS, try OSVersion("14.0"))
        XCTAssertEqual(aliases[1].iOS, try OSVersion("16.0"))
        XCTAssertEqual(aliases[1].macOS, try OSVersion("12.0"))
    }

    func testAllAffectedBranchesAndLeavesReceiveExactlyOneAlias() throws {
        let catalog = try Catalog(entries: [
            entry("tree", "20.0", "20.0"), entry("tree.branch"), entry("tree.branch.leaf", "14.0", "12.0"),
            entry("tree.namespace.leaf"), entry("tree.newer", "21.0", "21.0"),
            entry("safe"), entry("safe.leaf"), entry("other.namespace.leaf")
        ])
        let aliases = SwiftCatalogGenerator.compatibilityAliases(catalog: catalog)
        XCTAssertEqual(aliases.map(\.symbolName), ["tree.branch", "tree.branch.leaf", "tree.namespace.leaf"])
        XCTAssertEqual(Set(aliases.map(\.identifier)).count, 3)
        let noAliases = try Catalog(entries: [entry("safe"), entry("safe.leaf")])
        XCTAssertTrue(SwiftCatalogGenerator.compatibilityAliases(catalog: noAliases).isEmpty)
        XCTAssertFalse(SwiftCatalogGenerator.generate(catalog: noAliases).contains("// Direct aliases"))
    }

    func testCollisionResolutionPreservesRootsAndUnambiguousNaturalAliases() throws {
        let catalog = try Catalog(entries: [
            entry("a", "15.0", "12.0"), entry("a.b"), entry("a.b_u612e62"),
            entry("a_b"), entry("a_b_u612e62_2"),
            entry("x", "15.0", "12.0"), entry("x.y_z"),
            entry("x_y", "15.0", "12.0"), entry("x_y.z"),
            entry("untouched", "15.0", "12.0"), entry("untouched.child")
        ])
        let aliases = SwiftCatalogGenerator.compatibilityAliases(catalog: catalog)
        let names = Dictionary(uniqueKeysWithValues: aliases.map { ($0.symbolName, $0.identifier) })
        // The first suffix is an unaffected alias's natural name, the second is a root.
        XCTAssertEqual(names["a.b"], "a_b_u612e62_3")
        XCTAssertEqual(names["a.b_u612e62"], "a_b_u612e62")
        // Both ambiguous natural aliases receive a full-name suffix; neither wins by input order.
        XCTAssertEqual(names["x.y_z"], "x_y_z_u782e795f7a")
        XCTAssertEqual(names["x_y.z"], "x_y_z_u785f792e7a")
        XCTAssertEqual(names["untouched.child"], "untouched_child")
        let roots = Set(catalog.entries.map { SwiftCatalogGenerator.identifier(for: String($0.name.split(separator: ".")[0])) })
        XCTAssertTrue(roots.isDisjoint(with: aliases.map(\.identifier)))
        XCTAssertEqual(Set(aliases.map(\.identifier)).count, aliases.count)
        let reversed = try Catalog(entries: Array(catalog.entries.reversed()))
        XCTAssertEqual(aliases, SwiftCatalogGenerator.compatibilityAliases(catalog: reversed))
        XCTAssertEqual(SwiftCatalogGenerator.generate(catalog: catalog), SwiftCatalogGenerator.generate(catalog: reversed))
    }

    func testAliasesReuseComponentEncodingForNumbersKeywordsAndReservedNames() throws {
        let catalog = try Catalog(entries: [
            entry("0", "15.0", "12.0"), entry("0.4k"), entry("0.repeat"),
            entry("0.name"), entry("0._0"), entry("0.foo-bar")
        ])
        let aliases = SwiftCatalogGenerator.compatibilityAliases(catalog: catalog)
        let names = Dictionary(uniqueKeysWithValues: aliases.map { ($0.symbolName, $0.identifier) })
        XCTAssertEqual(names["0.4k"], "_0__4k")
        XCTAssertEqual(names["0.repeat"], "_0_repeat")
        XCTAssertEqual(names["0.name"], "_0__u6e616d65")
        XCTAssertEqual(names["0._0"], "_0__u5f30")
        XCTAssertEqual(names["0.foo-bar"], "_0__u666f6f2d626172")
    }
}

#if os(macOS) || os(Linux)
extension CompatibilityAliasTests {
    func testGeneratedAliasesCompileWithCollisionsAndContextualLookup() throws {
        let catalog = try Catalog(entries: [
            entry("asterisk", "15.0", "12.0"), entry("asterisk.circle"),
            entry("a", "15.0", "12.0"), entry("a.b"), entry("a_b"),
            entry("x", "15.0", "12.0"), entry("x.y_z"),
            entry("x_y", "15.0", "12.0"), entry("x_y.z"),
            entry("0", "15.0", "12.0"), entry("0.4k"), entry("0.repeat"), entry("0.name")
        ])
        let generated = SwiftCatalogGenerator.generate(catalog: catalog)
        let aliases = SwiftCatalogGenerator.compatibilityAliases(catalog: catalog)
        let calls = aliases.map { "    accepts(.\($0.identifier))" }.joined(separator: "\n")
        let source = """
        public protocol SymbolValue: Hashable, Sendable { var name: String { get } }
        public struct Symbol: SymbolValue {
            public let name: String
            internal init(name: String) { self.name = name }
        }
        \(generated)
        @available(iOS 13.0, macOS 11.0, *)
        func verifyAliasesAtNativeAvailability() {
            func accepts<S: SymbolValue>(_ value: S) {}
        \(calls)
            let _: Symbol = Symbol.asterisk_circle
        }
        """
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TypedSymbols-alias-compile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("Aliases.swift")
        try source.write(to: input, atomically: true, encoding: .utf8)
        let log = directory.appendingPathComponent("compiler.log")
        _ = FileManager.default.createFile(atPath: log.path, contents: nil)
        let output = try FileHandle(forWritingTo: log)
        defer { try? output.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var arguments = ["swiftc", "-swift-version", "5", "-warnings-as-errors", "-typecheck", "-module-cache-path", directory.appendingPathComponent("ModuleCache").path]
        #if os(macOS)
        #if arch(arm64)
        arguments += ["-target", "arm64-apple-macosx11.0"]
        #else
        arguments += ["-target", "x86_64-apple-macosx11.0"]
        #endif
        #endif
        process.arguments = arguments + [input.path]
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let diagnostics = try String(contentsOf: log, encoding: .utf8)
        XCTAssertEqual(process.terminationStatus, 0, diagnostics)
    }
}
#endif
