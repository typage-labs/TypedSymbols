/// A value naming a concrete SF Symbol.
///
/// Generated paths conform only when the complete path exists in the source
/// catalogue. Prefixes used only for navigation do not conform.
public protocol SymbolValue: Hashable, Sendable {
    var name: String { get }
}

/// A lightweight SF Symbol value and the entry point for the generated catalogue.
///
/// Use generated members such as `Symbol.bell.circle.fill`. Branch symbols have
/// their own generated types; convert them to `Symbol` when a common stored type
/// is useful, for example `let favorites = [Symbol(.bell), Symbol(.lock)]`.
public struct Symbol: SymbolValue {
    public let name: String

    // Only generated code in this module may create a value from a raw name.
    init(name: String) {
        self.name = name
    }

    /// Stores an existing typed symbol in the common value type.
    public init<S: SymbolValue>(_ symbol: S) {
        self.name = symbol.name
    }
}
