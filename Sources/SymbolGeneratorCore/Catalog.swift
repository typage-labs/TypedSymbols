import Foundation

public enum CatalogError: Error, CustomStringConvertible, Equatable {
    case invalidMetadata(String)
    case invalidName(String)
    case invalidVersion(String)
    case conflictingDuplicate(String)
    case ambiguousUnicodePrefix

    public var description: String {
        switch self {
        case .invalidMetadata(let detail): return "Invalid availability metadata: \(detail)"
        case .invalidName(let name): return "Invalid symbol name: \(String(reflecting: name))"
        case .invalidVersion(let version): return "Invalid OS version: \(String(reflecting: version))"
        case .conflictingDuplicate(let name): return "Conflicting availability for duplicate symbol: \(name)"
        case .ambiguousUnicodePrefix: return "Canonically equivalent symbol prefixes have different UTF-8 encodings"
        }
    }
}

/// A version read directly from Apple's release map, never inferred from a year.
public struct OSVersion: Hashable, Comparable, Sendable, CustomStringConvertible {
    private let components: [Int]

    public init(_ text: String) throws {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count), parts.allSatisfy({
            !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) }
                && Int($0).map { (0...9999).contains($0) } == true
        }) else { throw CatalogError.invalidVersion(text) }
        var numbers = parts.map { Int($0)! }
        while numbers.count > 2 && numbers.last == 0 { numbers.removeLast() }
        if numbers.count == 1 { numbers.append(0) }
        self.components = numbers
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        for index in 0..<max(lhs.components.count, rhs.components.count) {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public var description: String { components.map(String.init).joined(separator: ".") }
}

public struct CatalogEntry: Hashable, Sendable {
    public let name: String
    public let iOS: OSVersion
    public let macOS: OSVersion

    public init(name: String, iOS: String, macOS: String) throws {
        guard !name.isEmpty,
              !name.split(separator: ".", omittingEmptySubsequences: false).contains(where: \.isEmpty),
              !name.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) })
        else { throw CatalogError.invalidName(name) }
        self.name = name
        self.iOS = try OSVersion(iOS)
        self.macOS = try OSVersion(macOS)
    }
}

/// Normalized names and introductions. Original Apple files are read locally, not bundled.
public struct Catalog: Sendable {
    public let entries: [CatalogEntry]

    public init(entries: [CatalogEntry]) throws {
        guard !entries.isEmpty else { throw CatalogError.invalidMetadata("the symbol table is empty") }
        var unique: [String: CatalogEntry] = [:]
        var prefixBytes: [String: [UInt8]] = [:]
        for entry in entries {
            // Swift String equality normalizes Unicode, while emitted identifiers
            // preserve the original bytes. Reject ambiguous spellings before either
            // the symbol dictionary or the trie can merge them in input order.
            var prefix = ""
            for component in entry.name.split(separator: ".") {
                prefix += (prefix.isEmpty ? "" : ".") + component
                let bytes = Array(prefix.utf8)
                if let previous = prefixBytes[prefix], previous != bytes {
                    throw CatalogError.ambiguousUnicodePrefix
                }
                prefixBytes[prefix] = bytes
            }
            if let old = unique[entry.name], old != entry {
                throw CatalogError.conflictingDuplicate(entry.name)
            }
            unique[entry.name] = entry
        }
        self.entries = unique.values.sorted { $0.name < $1.name }
    }

    /// Reads `name_availability.plist` from SF Symbols or CoreGlyphs.
    public init(data: Data) throws {
        let propertyList: Any
        do {
            propertyList = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            throw CatalogError.invalidMetadata("not a readable property list")
        }
        guard let root = propertyList as? NSDictionary,
              let symbols = root["symbols"] as? NSDictionary,
              let releases = root["year_to_release"] as? [String: [String: String]]
        else {
            throw CatalogError.invalidMetadata("expected symbols and year_to_release dictionaries")
        }
        var entries: [CatalogEntry] = []
        // Keep NSString keys until validation: bridging this dictionary to Swift
        // first would silently merge canonically equivalent Unicode names.
        for (rawName, rawRelease) in symbols {
            guard let name = rawName as? String, let key = rawRelease as? String else {
                throw CatalogError.invalidMetadata("expected string symbol names and release keys")
            }
            guard let release = releases[key] else {
                throw CatalogError.invalidMetadata("symbol \(name) references missing release \(key)")
            }
            guard let iOS = release["iOS"], let macOS = release["macOS"] else {
                throw CatalogError.invalidMetadata("release \(key) has no iOS/macOS introduction")
            }
            entries.append(try CatalogEntry(name: name, iOS: iOS, macOS: macOS))
        }
        try self.init(entries: entries)
    }
}
