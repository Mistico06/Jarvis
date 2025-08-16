// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MLCSwift",
    products: [
        .library(
            name: "MLCSwift",
            targets: ["MLCEngineObjC", "MLCSwift"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MLCEngineObjC",
            path: "ios/MLCSwift/Sources/ObjC",
            cxxSettings: [
                .define("TVM_ALWAYS_INLINE", to: "__attribute__((always_inline)) inline"),
                .headerSearchPath("../../../../3rdparty/tvm/include"),
                .headerSearchPath("../../../../3rdparty/tvm/ffi/include"),
                .headerSearchPath("../../../../3rdparty/tvm/3rdparty/dmlc-core/include"),
                .headerSearchPath("../../../../3rdparty/tvm/3rdparty/dlpack/include"),
            ]
        ),
        .target(
            name: "MLCSwift",
            dependencies: ["MLCEngineObjC"],
            path: "ios/MLCSwift/Sources/Swift"
        )
    ],
    cxxLanguageStandard: .cxx17
)