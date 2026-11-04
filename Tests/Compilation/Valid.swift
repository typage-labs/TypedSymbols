import SwiftUI
import TypedSymbols

func basicUsage() {
    let _: String = Symbol.bell.circle.fill.name
    let _ = Image(symbol: .bell)
    let _ = Image(symbol: .bell.circle)
    let _ = Image(symbol: .bell.circle.fill)
    let _ = Image(symbol: .lock.shield.fill)
    let _ = Image(symbol: ._0.circle)
    let _ = Image(symbol: .repeat)
    let _: Symbol = .asterisk_circle
    let _: String = Symbol.asterisk_circle.name
    let _ = Image(symbol: .asterisk_circle)
    if #available(iOS 14.0, macOS 11.0, *) {
        let _ = Label("Notifications", symbol: .bell.fill)
        let title = String("Notifications")
        let _ = Label(title, symbol: .bell.fill)
    }
    let _ = Image(systemName: "bell")
    let _: Set<Symbol> = [Symbol(.bell), Symbol(.bell.fill)]
}

@available(iOS 15.0, macOS 12.0, *)
func availableUsage() {
    let _ = Image(symbol: .arrow.down.to.line.circle)
    let _: String = Symbol.asterisk.circle.name
    // The alias preserves iOS 15 / macOS 12 even though clock.badge needs 16 / 13.
    let _ = Image(symbol: .clock_badge_checkmark)
}
