// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Jarvis",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17) // Raised deployment target to iOS 17
    ],
    products: [
        .library(
            name: "AppModule",
            type: .static,
            targets: ["AppModule"]
        )
    ],
    dependencies: [
        // MLC LLM runtime
        .package(url: "https://github.com/Mistico06/mlc-llm.git", branch: "main"),
        // Crypto primitives
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
        // SQLite wrapper
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.13.0")
    ],
    targets: [
        .target(
            name: "AppModule",
            dependencies: [
                .product(name: "MLCSwift", package: "mlc-llm"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources/AppModule" // Ensure this matches your folder layout
        )
    ]
)
