import Foundation
import XCTest
@testable import SymbolGeneratorCore

final class SymbolGeneratorCoreTests: XCTestCase {
    private func entry(_ name: String, _ iOS: String = "13.0", _ macOS: String = "10.15") throws -> CatalogEntry {
        try CatalogEntry(name: name, iOS: iOS, macOS: macOS)
    }

    private func metadata(symbols: [String: String], releases: [String: [String: String]]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: ["symbols": symbols, "year_to_release": releases], format: .binary, options: 0)
    }

    func testReadsRealMetadataSchemaWithoutInferringVersionsFromYears() throws {
        let catalog = try Catalog(data: metadata(
            symbols: ["bell.fill": "arbitrary-release", "bell": "arbitrary-release"],
            releases: ["arbitrary-release": ["iOS": "26.1", "macOS": "26.0", "watchOS": "26.1"]]
        ))
        XCTAssertEqual(catalog.entries.map(\.name), ["bell", "bell.fill"])
        XCTAssertEqual(catalog.entries[0].iOS.description, "26.1")
        XCTAssertEqual(catalog.entries[0].macOS.description, "26.0")
    }

    func testDeterministicRegardlessOfOrderAndExactDuplicates() throws {
        let entries = try [entry("bell.circle.fill"), entry("bell"), entry("0.circle"), entry("bell.circle")]
        let a = SwiftCatalogGenerator.generate(catalog: try Catalog(entries: entries))
        let b = SwiftCatalogGenerator.generate(catalog: try Catalog(entries: entries.reversed() + entries))
        XCTAssertEqual(a, b)
        XCTAssertEqual(try Catalog(entries: entries + entries).entries.count, 4)
        XCTAssertTrue(a.hasSuffix("\n"))
        XCTAssertFalse(a.contains("/Applications/"))
    }

    func testOnlyRealSymbolsHaveNameAndSymbolValueConformance() throws {
        let source = SwiftCatalogGenerator.generate(catalog: try Catalog(entries: [entry("bell"), entry("bell.circle.fill"), entry("arrow.down")]))
        XCTAssertTrue(source.contains("public struct _Branch_bell: SymbolValue"))
        XCTAssertTrue(source.contains("public var name: String { \"bell\" }"))
        XCTAssertTrue(source.contains("public struct _Branch_circle: Hashable, Sendable"))
        XCTAssertTrue(source.contains("public struct _Branch_arrow: Hashable, Sendable"))
        XCTAssertFalse(source.contains("public var name: String { \"bell.circle\" }"))
        XCTAssertTrue(source.contains("public var `fill`: Symbol { .init(name: \"bell.circle.fill\") }"))
        XCTAssertTrue(source.contains("public extension SymbolValue where Self == Symbol"))
        XCTAssertFalse(source.contains("dynamicMemberLookup"))
        XCTAssertFalse(source.contains("public init"))
    }

    func testIdentifierMappingIsInjectiveAndStableAcrossSiblings() throws {
        let components = ["0", "00", "0percent", "_0", "_u30", "name", "hash", "hashValue", "init", "self", "Self", "Type", "Protocol", "class", "repeat", "foo-bar", "foo_bar", "foo/bar", "é", "bell"]
        let mapped = components.map(SwiftCatalogGenerator.identifier(for:))
        XCTAssertEqual(Set(mapped).count, components.count)
        XCTAssertEqual(SwiftCatalogGenerator.identifier(for: "0"), "_0")
        XCTAssertEqual(SwiftCatalogGenerator.identifier(for: "4k"), "_4k")
        XCTAssertEqual(SwiftCatalogGenerator.identifier(for: "_0"), "_u5f30")
        XCTAssertEqual(SwiftCatalogGenerator.identifier(for: "name"), "_u6e616d65")
        XCTAssertEqual(SwiftCatalogGenerator.identifier(for: "foo-bar"), "_u666f6f2d626172")
        XCTAssertEqual(SwiftCatalogGenerator.identifier(for: "repeat"), "repeat")
        let source = SwiftCatalogGenerator.generate(catalog: try Catalog(entries: components.map { try entry("root." + $0) }))
        XCTAssertTrue(source.contains("public var `repeat`: Symbol"))
        XCTAssertTrue(source.contains("public var `class`: Symbol"))
        XCTAssertTrue(source.contains("public var `_0`: Symbol { .init(name: \"root.0\") }"))
        XCTAssertTrue(source.contains("public var `_u6e616d65`: Symbol { .init(name: \"root.name\") }"))
    }

    func testAvailabilityIsConservativeAlongEveryPath() throws {
        let source = SwiftCatalogGenerator.generate(catalog: try Catalog(entries: [
            entry("asterisk", "15.0", "12.0"),
            entry("asterisk.circle", "13.0", "10.15"),
            entry("asterisk.circle.fill", "16.1", "13.0"),
            entry("arrow.down", "14.0", "11.0")
        ]))
        XCTAssertTrue(source.contains("@available(iOS 15.0, macOS 12.0, *)\n    static var `asterisk`"))
        XCTAssertTrue(source.contains("@available(iOS 15.0, macOS 12.0, *)\n        public var `circle`"))
        XCTAssertTrue(source.contains("@available(iOS 16.1, macOS 13.0, *)\n            public var `fill`"))
        // Navigation-only prefixes are safe without claiming to render a symbol.
        XCTAssertTrue(source.contains("@available(iOS 13.0, macOS 11.0, *)\n    static var `arrow`"))
        XCTAssertTrue(source.contains("@available(iOS 14.0, macOS 11.0, *)\n        public var `down`"))
    }

    func testRejectsMalformedMetadataRatherThanGuessingAvailability() throws {
        XCTAssertThrowsError(try Catalog(data: Data("not a plist".utf8)))
        let badRoot = try PropertyListSerialization.data(fromPropertyList: ["symbols": ["bell": "2019"]], format: .xml, options: 0)
        XCTAssertThrowsError(try Catalog(data: badRoot))
        XCTAssertThrowsError(try Catalog(data: metadata(symbols: ["bell": "missing"], releases: [:])))
        XCTAssertThrowsError(try Catalog(data: metadata(symbols: ["bell": "release"], releases: ["release": ["iOS": "13.0"]])))
        XCTAssertThrowsError(try Catalog(data: metadata(symbols: [:], releases: [:])))
        XCTAssertThrowsError(try Catalog(data: metadata(symbols: ["bell": "release"], releases: ["release": ["iOS": "new", "macOS": "11.0"]])))
    }

    func testRejectsInvalidNamesAndConflictingDuplicates() throws {
        for name in ["", ".bell", "bell.", "bell..fill", " bell", "bell\nfill", "bell.fill ", "bell\u{0}fill"] {
            XCTAssertThrowsError(try entry(name), name)
        }
        XCTAssertThrowsError(try Catalog(entries: []))
        XCTAssertThrowsError(try Catalog(entries: [entry("bell"), entry("bell", "14.0", "11.0")])) { error in
            XCTAssertEqual(error as? CatalogError, .conflictingDuplicate("bell"))
        }
    }

    func testVersionsCompareNumericallyAndNormalizeEquivalentInputs() throws {
        XCTAssertLessThan(try OSVersion("9.2"), try OSVersion("10.0"))
        XCTAssertLessThan(try OSVersion("13.2"), try OSVersion("13.10"))
        XCTAssertEqual(try OSVersion("13"), try OSVersion("13.0.0"))
        XCTAssertEqual(try OSVersion("13.00"), try OSVersion("13.0"))
        for version in ["", "-1", "13.", ".13", "13..1", "13.0.0.1", "13.beta", "13. 1", "999999999999999999999999"] {
            XCTAssertThrowsError(try OSVersion(version), version)
        }
    }

    func testRejectsCanonicallyEquivalentUnicodePrefixesInEitherOrder() throws {
        let ambiguousPairs = [
            ["root.é", "root.e\u{0301}"],
            ["root.é.x", "root.e\u{0301}.y"],
        ]
        for names in ambiguousPairs {
            let entries = try names.map { try entry($0) }
            for ordered in [entries, Array(entries.reversed())] {
                XCTAssertThrowsError(try Catalog(entries: ordered)) { error in
                    XCTAssertEqual(error as? CatalogError, .ambiguousUnicodePrefix)
                }
            }
        }
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
          <key>symbols</key><dict>
            <key>root.é</key><string>release</string>
            <key>root.e\u{0301}</key><string>release</string>
          </dict>
          <key>year_to_release</key><dict><key>release</key><dict>
            <key>iOS</key><string>13.0</string><key>macOS</key><string>11.0</string>
          </dict></dict>
        </dict></plist>
        """
        XCTAssertThrowsError(try Catalog(data: Data(xml.utf8))) { error in
            XCTAssertEqual(error as? CatalogError, .ambiguousUnicodePrefix)
        }
    }

    func testNamesAreEscapedInSwiftStringLiterals() throws {
        let source = SwiftCatalogGenerator.generate(catalog: try Catalog(entries: [entry("a.quoted\"slash\\")]))
        XCTAssertTrue(source.contains(".init(name: \"a.quoted\\\"slash\\\\\")"))
    }
}

#if os(macOS) || os(Linux)
extension SymbolGeneratorCoreTests {
    /// Compile the generator's output, including identifier cases absent from today's Apple catalogue.
    func testSyntheticCollisionCatalogueActuallyCompiles() throws {
        let names = ["root", "root.0", "root.4k", "root._0", "root.name", "root.hash", "root.hashValue", "root.init", "root.self", "root.Self", "root.Type", "root.Protocol", "root.class", "root.repeat", "root.foo-bar", "root.foo_bar", "root.é", "root.namespace.leaf", "root.Symbol", "root.bell", "Symbol", "Symbol.child", "String.child", "SymbolValue.child", "Hashable.child", "Sendable.child"]
        let source = SwiftCatalogGenerator.generate(catalog: try Catalog(entries: names.map { try entry($0) }))
        let stub = """
        public protocol SymbolValue: Hashable, Sendable { var name: String { get } }
        public struct Symbol: SymbolValue {
            public let name: String
            internal init(name: String) { self.name = name }
        }
        """
        let uses = """
        @available(iOS 13.0, macOS 11.0, *)
        func verifyGeneratedPaths() {
            func accepts<S: SymbolValue>(_ value: S) {}
            accepts(.root)
            accepts(.root._0)
            accepts(.root._4k)
            accepts(.root._u5f30)
            accepts(.root._u6e616d65)
            accepts(.root._u68617368)
            accepts(.root._u6861736856616c7565)
            accepts(.root._u696e6974)
            accepts(.root._u73656c66)
            accepts(.root._u53656c66)
            accepts(.root._u54797065)
            accepts(.root._u50726f746f636f6c)
            accepts(.root.class)
            accepts(.root.repeat)
            accepts(.root._u666f6f2d626172)
            accepts(.root.foo_bar)
            accepts(.root._uc3a9)
            accepts(.root.namespace.leaf)
            accepts(.root.Symbol)
            accepts(.root.bell)
            accepts(.Symbol)
            accepts(.Symbol.child)
            accepts(.String.child)
            accepts(.SymbolValue.child)
            accepts(.Hashable.child)
            accepts(.Sendable.child)
        }
        """
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TypedSymbols-compile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("Synthetic.swift")
        try (stub + "\n" + source + "\n" + uses).write(to: input, atomically: true, encoding: .utf8)
        let log = directory.appendingPathComponent("compiler.log")
        _ = FileManager.default.createFile(atPath: log.path, contents: nil)
        let output = try FileHandle(forWritingTo: log)
        defer { try? output.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swiftc", "-swift-version", "5", "-typecheck", "-module-cache-path", directory.appendingPathComponent("ModuleCache").path, input.path]
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let diagnostics = try String(contentsOf: log, encoding: .utf8)
        XCTAssertEqual(process.terminationStatus, 0, diagnostics)
    }
}
#endif
