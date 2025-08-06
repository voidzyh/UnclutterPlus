// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UnclutterPlus",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "UnclutterPlus",
            targets: ["UnclutterPlus"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "UnclutterPlus",
            dependencies: [
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "UnclutterPlusTests", 
            dependencies: ["UnclutterPlus"]
        ),
    ]
)