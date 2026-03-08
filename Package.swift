// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MoodleHelper",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "MoodleHelper",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/MoodleHelper",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
