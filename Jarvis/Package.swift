// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Jarvis",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Define a library product for your AppModule target
        .library(
            name: "AppModule",
            type: .static,
            targets: ["AppModule"]
        )
    ],
    dependencies: [
        // Local mlc-llm Swift package at the correct folder containing Package.swift
        .package(name: "mlc-llm", path: "ThirdParty/mlc-llm/ios/MLCSwift"),

        // Additional remote package dependencies
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
            ]
            // If you have a custom sources folder, uncomment and set the path:
            // path: "Sources/AppModule"
        )
    ]
)
