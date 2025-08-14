// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jarvis",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v16) // optional, if you're targeting iOS too
    ],
    products: [
        .executable(name: "Jarvis", targets: ["Jarvis"]),
    ],
    dependencies: [
        // your dependencies here
    ],
    targets: [
        .target(
            name: "Jarvis",
            dependencies: []
        ),
        .testTarget(
            name: "JarvisTests",
            dependencies: ["Jarvis"]
        )
    ]
)
