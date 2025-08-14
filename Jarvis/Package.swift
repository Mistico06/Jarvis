// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jarvis",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .executable(name: "Jarvis", targets: ["Jarvis"])
    ],
    dependencies: [
        .package(path: "ThirdParty/mlc-llm/ios/MLCSwift"),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0"..<"4.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1")
    ],
    targets: [
        .executableTarget(
            name: "Jarvis",
            dependencies: [
                // ✅ Change this line - use the actual package name from MLCSwift's Package.swift
                .product(name: "MLCSwift", package: "mlc-llm"),  // Package name should match the target Package.swift
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources/App"
        )
    ]
)
