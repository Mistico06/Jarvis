// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Jarvis",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AppModule",
            type: .static,
            targets: ["AppModule"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Mistico06/mlc-llm.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
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
