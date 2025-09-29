// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "subtree",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "subtree", targets: ["Subtree"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.6.1"),
        .package(url: "https://github.com/jpsim/Yams.git", exact: "6.1.0"),
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.1.0"),
        .package(url: "https://github.com/SwiftPackageIndex/SemanticVersion.git", exact: "0.5.1"),
        .package(
            url: "https://github.com/apple/swift-system",
            // Temporarily pin to 1.5.0 because 1.6.0 has a breaking change for Ubuntu Focal
            // https://github.com/apple/swift-system/issues/237
            exact: "1.5.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "Subtree",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "SemanticVersion", package: "SemanticVersion"),
                .product(name: "SystemPackage", package: "swift-system"),
            ]
        ),
        .testTarget(
            name: "SubtreeTests",
            dependencies: [
                "Subtree",
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "SystemPackage", package: "swift-system"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Testing")
            ]
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "Subtree",
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "SystemPackage", package: "swift-system"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Testing")
            ]
        ),
    ]
)
