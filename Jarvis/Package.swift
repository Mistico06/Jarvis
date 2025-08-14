// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jarvis",
    platforms: [
        .macOS(.v11),
        .iOS(.v16),
    ],
    products: [
        .executable(name: "Jarvis", targets: ["Jarvis"])
    ],
    dependencies: [
        // Local dependency: mlc-llm cloned in ThirdParty
        .package(path: "./Jarvis/ThirdParty/mlc-llm/ios/MLCSwift"),
        // Other dependencies
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0"..<"4.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1")
    ],
    targets: [
        .executableTarget(
            name: "Jarvis",
            dependencies: [
                .product(name: "MLCSwift", package: "MLCSwift"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources/App"
        )
    ]
)
