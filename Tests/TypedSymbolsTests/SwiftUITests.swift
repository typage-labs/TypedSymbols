#if canImport(SwiftUI)
import SwiftUI
import XCTest
import TypedSymbols

final class SwiftUITests: XCTestCase {
    func testImageSupportsImplicitMemberLookup() {
        let intermediate: Image = Image(symbol: .bell)
        let terminal: Image = Image(symbol: .bell.circle.fill)
        XCTAssertEqual(intermediate, Image(systemName: "bell"))
        XCTAssertEqual(terminal, Image(systemName: "bell.circle.fill"))
    }

    func testImageSupportsCompatibilityAliasAtTheBaseline() {
        let alias: Image = Image(symbol: .asterisk_circle)
        XCTAssertEqual(alias, Image(systemName: "asterisk.circle"))
        if #available(iOS 15.0, macOS 12.0, *) {
            XCTAssertEqual(alias, Image(symbol: .asterisk.circle))
        }
    }

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testLabelSupportsLocalizedAndStringTitles() {
        let localized: LocalizedStringKey = "Notifications"
        let text: String = "Notifications"
        let substring = text.prefix(5)
        let _: Label<Text, Image> = Label("Notifications", symbol: .bell.fill)
        let _: Label<Text, Image> = Label(localized, symbol: .bell.fill)
        let _: Label<Text, Image> = Label(text, symbol: .bell.fill)
        let _: Label<Text, Image> = Label(substring, symbol: .bell.fill)
    }

    func testExistingSwiftUIInitializersRemainAvailable() {
        let image = Image(systemName: "bell")
        XCTAssertEqual(image, Image(symbol: .bell))
        if #available(iOS 14.0, macOS 11.0, *) {
            let _: Label<Text, Image> = Label("Notifications", systemImage: "bell")
        }
    }
}
#endif
