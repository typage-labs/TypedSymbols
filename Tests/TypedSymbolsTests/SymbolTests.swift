import XCTest
import TypedSymbols

final class SymbolTests: XCTestCase {
    func testIntermediateSymbolsRetainTheirNames() {
        XCTAssertEqual(Symbol.bell.name, "bell")
        XCTAssertEqual(Symbol.bell.circle.name, "bell.circle")
        XCTAssertEqual(Symbol.lock.shield.name, "lock.shield")
        XCTAssertEqual(Symbol.arrow.down.name, "arrow.down")
        XCTAssertEqual(Symbol.arrow.down.to.line.name, "arrow.down.to.line")
    }

    func testCompletePathsRetainTheirNames() {
        XCTAssertEqual(Symbol.bell.fill.name, "bell.fill")
        XCTAssertEqual(Symbol.bell.circle.fill.name, "bell.circle.fill")
        XCTAssertEqual(Symbol.lock.shield.fill.name, "lock.shield.fill")
        if #available(iOS 15.0, macOS 12.0, *) {
            XCTAssertEqual(Symbol.arrow.down.to.line.circle.name, "arrow.down.to.line.circle")
        }
    }

    func testNumericComponentsAndSwiftKeywords() {
        XCTAssertEqual(Symbol._0.circle.name, "0.circle")
        XCTAssertEqual(Symbol._0.circle.fill.name, "0.circle.fill")
        XCTAssertEqual(Symbol.repeat.name, "repeat")
    }

    func testCompatibilityAliasPreservesTheHierarchicalName() {
        // This alias is available at the package's baseline, before its parent.
        let alias: Symbol = .asterisk_circle
        XCTAssertEqual(alias.name, "asterisk.circle")
        if #available(iOS 15.0, macOS 12.0, *) {
            XCTAssertEqual(alias.name, Symbol.asterisk.circle.name)
            XCTAssertEqual(alias, Symbol(.asterisk.circle))
        }
    }

    func testCompatibilityAliasPreservesLaterNativeAvailability() {
        if #available(iOS 15.0, macOS 12.0, *) {
            XCTAssertEqual(Symbol.clock_badge_checkmark.name, "clock.badge.checkmark")
        }
        if #available(iOS 16.0, macOS 13.0, *) {
            XCTAssertEqual(Symbol.clock_badge_checkmark, Symbol(.clock.badge.checkmark))
        }
    }

    func testSymbolsCanBeStoredInACommonValueType() {
        let favorites: [Symbol] = [Symbol(.bell), Symbol(.bell.circle.fill), Symbol(.lock.shield)]
        XCTAssertEqual(favorites.map(\.name), ["bell", "bell.circle.fill", "lock.shield"])
        XCTAssertEqual(Symbol(Symbol.bell), Symbol(.bell))
        XCTAssertNotEqual(Symbol(.bell), Symbol(.bell.fill))
        XCTAssertEqual(Set([Symbol(.bell), Symbol(.bell), Symbol(.bell.fill)]).count, 2)
    }

    func testGeneratedValuesAreHashableAndSendable() {
        func requireValue<S: SymbolValue>(_ value: S) -> String {
            var values = Set<S>()
            values.insert(value)
            values.insert(value)
            XCTAssertEqual(values.count, 1)
            return requireSendable(value).name
        }
        func requireSendable<S: Sendable>(_ value: S) -> S { value }

        XCTAssertEqual(requireValue(Symbol.bell), "bell")
        XCTAssertEqual(requireValue(Symbol.bell.circle.fill), "bell.circle.fill")
    }

    func testGenericImplicitMemberLookup() {
        func name<S: SymbolValue>(of symbol: S) -> String { symbol.name }
        XCTAssertEqual(name(of: .bell), "bell")
        XCTAssertEqual(name(of: .bell.circle.fill), "bell.circle.fill")
    }
}
