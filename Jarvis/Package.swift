// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Jarvis",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .executable(name: "Jarvis", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/mlc-ai/mlc-llm.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0"..<"4.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "MLCLLMSwift", package: "mlc-llm"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources/App",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "JarvisTests",
            dependencies: ["App"],
            path: "Tests/JarvisTests"
        )
    ]
)
