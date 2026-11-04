// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TypedSymbols",
    platforms: [.iOS(.v13), .macOS(.v11)],
    products: [
        .library(name: "TypedSymbols", targets: ["TypedSymbols"]),
        .executable(name: "GenerateSymbols", targets: ["GenerateSymbols"]),
    ],
    targets: [
        .target(name: "TypedSymbols"),
        .target(name: "SymbolGeneratorCore"),
        .executableTarget(name: "GenerateSymbols", dependencies: ["SymbolGeneratorCore"]),
        .testTarget(name: "TypedSymbolsTests", dependencies: ["TypedSymbols"]),
        .testTarget(name: "SymbolGeneratorCoreTests", dependencies: ["SymbolGeneratorCore"]),
    ]
)
