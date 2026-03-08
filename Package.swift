// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MoodleHelper",
    platforms: [.macOS(.v26), .iOS(.v18)],
    products: [
        .library(name: "MoodleHelperCore", targets: ["MoodleHelperCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "MoodleHelperCore",
            path: "Sources/MoodleHelperCore",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .executableTarget(
            name: "MoodleHelper",
            dependencies: [
                "MoodleHelperCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/MoodleHelper",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
