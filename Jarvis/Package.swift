// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Jarvis",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .app(name: "Jarvis", targets: ["AppModule"])
    ],
    dependencies: [
        // Existing packages
        .package(path: "ThirdParty/mlc-llm/ios/MLCSwift"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.13.0"),

        // Add mlc-llm itself:
        .package(name: "mlc-llm", path: "ThirdParty/mlc-llm")
    ],
    targets: [
        .target(
            name: "AppModule",
            dependencies: [
                .product(name: "MLCSwift", package: "mlc-llm"),
                .product(name: "Crypto",    package: "swift-crypto"),
                .product(name: "SQLite",    package: "SQLite.swift")
            ]
        ),
        .testTarget(
            name: "AppModuleTests",
            dependencies: ["AppModule"]
        ),
    ]
)
