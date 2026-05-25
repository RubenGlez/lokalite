// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lokalite",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LokaliteCore", targets: ["LokaliteCore"]),
        .executable(name: "lokalite", targets: ["lokalite"]),
        .executable(name: "LokaliteApp", targets: ["LokaliteApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/P-H-C/phc-winner-argon2.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "LokaliteCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "argon2", package: "phc-winner-argon2"),
            ],
            path: "Sources/LokaliteCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "lokalite",
            dependencies: [
                "LokaliteCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/lokalite",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "LokaliteApp",
            dependencies: ["LokaliteCore"],
            path: "Sources/LokaliteApp",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "LokaliteCoreTests",
            dependencies: ["LokaliteCore"],
            path: "Tests/LokaliteCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
