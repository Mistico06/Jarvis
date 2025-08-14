// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Jarvis",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "AppModule",
            type: .static,
            targets: ["AppModule"]
        )
    ],
    dependencies: [
        .package(name: "mlc-llm", path: "ThirdParty/mlc-llm/ios/MLCSwift"),
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
            path: "Sources/AppModule", // Ensure this matches your folder layout
            cxxSettings: [
                .unsafeFlags(["-std=c++17"])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-LThirdParty/mlc-llm/ios/MLCSwift/lib", // update this path to where the .a files live
                    "-Wl,-all_load",
                    "-lmodel_iphone",
                    "-lmlc_llm",
                    "-ltvm_runtime",
                    "-ltokenizers_cpp",
                    "-lsentencepiece",
                    "-ltokenizers_c",
                    "-Wl,-noall_load"
                ])
            ]
        )
    ]
)
