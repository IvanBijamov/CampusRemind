// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CampusRemind",
    platforms: [.macOS(.v26), .iOS(.v18)],
    products: [
        .library(name: "CampusRemindCore", targets: ["CampusRemindCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "CampusRemindCore",
            path: "Sources/CampusRemindCore",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .executableTarget(
            name: "CampusRemind",
            dependencies: [
                "CampusRemindCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/CampusRemind",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
