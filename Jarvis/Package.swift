// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Jarvis",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // For an iOS app target, we declare a library so Xcode can embed it.
        .library(
            name: "AppModule",
            type: .static,
            targets: ["AppModule"]
        ),
    ],
    dependencies: [
        // Local mlc-llm Swift package
        .package(name: "mlc-llm", path: "ThirdParty/mlc-llm"),
        // Crypto and SQLite packages
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.13.0"),
    ],
    targets: [
        .target(
            name: "AppModule",
            dependencies: [
                .product(name: "MLCSwift", package: "mlc-llm"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "Sources/AppModule"
        )
    ]
)
