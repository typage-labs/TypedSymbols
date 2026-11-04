import Foundation
import SymbolGeneratorCore

struct Options {
    var input: String?
    var output = "Sources/TypedSymbols/Generated/SymbolCatalog.swift"
    var check = false

    init(arguments: [String]) throws {
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--input", "--output":
                index += 1
                guard index < arguments.count, !arguments[index].hasPrefix("--") else {
                    throw CLIError.message("\(argument) requires a path")
                }
                if argument == "--input" { input = arguments[index] } else { output = arguments[index] }
            case "--check": check = true
            default: throw CLIError.message("Unknown argument: \(argument)")
            }
            index += 1
        }
    }
}

enum CLIError: Error, CustomStringConvertible {
    case message(String)
    var description: String { switch self { case .message(let message): return message } }
}

let usage = """
Usage: swift run GenerateSymbols [--input PATH] [--output PATH] [--check]
Reads an installed name_availability.plist and emits a deterministic Swift catalogue.
Without --input, tries SF Symbols.app, then macOS CoreGlyphs.
--check compares the output without modifying it (nonzero exit when different).
"""

if CommandLine.arguments.dropFirst().contains("--help") {
    print(usage)
    exit(EXIT_SUCCESS)
}

do {
    let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
    let candidates = [
        "/Applications/SF Symbols.app/Contents/Resources/Metadata/name_availability.plist",
        "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist"
    ]
    guard let input = options.input ?? candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
        throw CLIError.message("No local catalogue found. Install SF Symbols or pass --input /path/to/name_availability.plist.")
    }
    let catalog = try Catalog(data: Data(contentsOf: URL(fileURLWithPath: input)))
    let generated = Data(SwiftCatalogGenerator.generate(catalog: catalog).utf8)
    let output = URL(fileURLWithPath: options.output).standardizedFileURL
    if options.check {
        guard let existing = try? Data(contentsOf: output), existing == generated else {
            throw CLIError.message("Generated catalogue differs: \(output.path). Regenerate using the intended metadata version.")
        }
        print("Verified \(catalog.entries.count) symbol names in \(output.path)")
    } else {
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try generated.write(to: output, options: .atomic)
        print("Generated \(catalog.entries.count) symbol names in \(output.path)")
    }
    print("Source: \(input)")
} catch {
    FileHandle.standardError.write(Data("GenerateSymbols: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}
