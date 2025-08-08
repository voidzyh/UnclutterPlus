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
            path: "Sources/UnclutterPlus",
            exclude: ["Info.plist"],
            resources: [
                .copy("Info.plist"),
                .copy("Resources/UnclutterPlus.icns")
            ]
        ),
        .testTarget(
            name: "UnclutterPlusTests", 
            dependencies: ["UnclutterPlus"],
            path: "Tests/UnclutterPlusTests"
        ),
    ]
)