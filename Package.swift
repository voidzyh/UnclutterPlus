// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UnclutterPlus",
    defaultLocalization: "en",
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
        // Full Markdown rendering in SwiftUI
        .package(url: "https://github.com/gonzalezreal/MarkdownUI.git", from: "2.0.0"),
        // Syntax highlighting for code blocks
        .package(url: "https://github.com/JohnSundell/Splash.git", from: "0.16.0")
    ],
    targets: [
        .executableTarget(
            name: "UnclutterPlus",
            dependencies: [
                .product(name: "MarkdownUI", package: "MarkdownUI"),
                .product(name: "Splash", package: "Splash")
            ],
            path: "Sources/UnclutterPlus",
            resources: [
                .copy("Resources/VERSION"),
                .copy("Resources/UnclutterPlus.icns"),
                .process("Resources/en.lproj"),
                .process("Resources/zh-Hans.lproj"),
                .process("Resources/zh-Hant.lproj"),
                .process("Resources/ja.lproj"),
                .process("Resources/ko.lproj"),
                .process("Resources/fr.lproj"),
                .process("Resources/de.lproj"),
                .process("Resources/es.lproj")
            ]
        ),
        .testTarget(
            name: "UnclutterPlusTests", 
            dependencies: ["UnclutterPlus"],
            path: "Tests/UnclutterPlusTests"
        ),
    ]
)