#if canImport(SwiftUI)
import SwiftUI

public extension Image {
    /// Creates an image from a statically generated SF Symbol path.
    init<S: SymbolValue>(symbol: S) {
        self.init(systemName: symbol.name)
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public extension Label where Title == Text, Icon == Image {
    /// Creates a label using SwiftUI's localized string key behavior.
    init<S: SymbolValue>(_ titleKey: LocalizedStringKey, symbol: S) {
        self.init(titleKey, systemImage: symbol.name)
    }

    /// Creates a label using SwiftUI's string value behavior.
    init<TitleString: StringProtocol, S: SymbolValue>(_ title: TitleString, symbol: S) {
        self.init(title, systemImage: symbol.name)
    }
}
#endif
