// swift-tools-version: 5.10
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
        // 使用兼容的版本
        .package(url: "https://github.com/gonzalezreal/MarkdownUI.git", from: "2.0.0"),
        // 使用最新兼容版本
        .package(url: "https://github.com/JohnSundell/Splash.git", from: "0.16.0"),
        // 移除不兼容的库，使用基础实现
    ],
    targets: [
        .executableTarget(
            name: "UnclutterPlus",
            dependencies: [
                .product(name: "MarkdownUI", package: "MarkdownUI"),
                .product(name: "Splash", package: "Splash"),
            ],
            path: "Sources/UnclutterPlus",
            exclude: [
                "Resources/Info.plist"
            ],
            resources: [
                .copy("Resources/UnclutterPlus.icns"),
                .process("Resources/en.lproj"),
                .process("Resources/zh-Hans.lproj"),
                .process("Resources/zh-Hant.lproj"),
                .process("Resources/ja.lproj"),
                .process("Resources/ko.lproj"),
                .process("Resources/fr.lproj"),
                .process("Resources/de.lproj"),
                .process("Resources/es.lproj")
            ],
            swiftSettings: [
                // 启用 Swift 5.10 的现代化特性
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImplicitOpenExistentials")
            ]
        ),
        .testTarget(
            name: "UnclutterPlusTests", 
            dependencies: ["UnclutterPlus"],
            path: "Tests/UnclutterPlusTests"
        ),
    ]
)