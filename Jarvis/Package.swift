// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jarvis",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v16)
    ],
    products: [
        .executable(name: "Jarvis", targets: ["Jarvis"]),
    ],
    dependencies: [
        // Add your dependencies here
    ],
    targets: [
        .executableTarget(
            name: "Jarvis",
            dependencies: [],
            path: "Sources/App"
        )
    ]
)
