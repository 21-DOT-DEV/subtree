// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "subtree",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // The subtree CLI executable
        .executable(
            name: "subtree",
            targets: ["subtree"]
        ),
        // The SubtreeLib library (for testing and future programmatic use)
        .library(
            name: "SubtreeLib",
            targets: ["SubtreeLib"]
        )
    ],
    dependencies: [
        // CLI argument parsing
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.6.2"),
        // YAML configuration
        .package(url: "https://github.com/jpsim/Yams.git", exact: "6.1.0"),
        // Process execution
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", exact: "0.2.1"),
        // File system operations (pinned for Ubuntu 20.04 compatibility)
        .package(
            url: "https://github.com/apple/swift-system",
            exact: "1.5.0"
        )
    ],
    targets: [
        // SubtreeLib: Library containing all business logic
        .target(
            name: "SubtreeLib",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "SystemPackage", package: "swift-system")
            ]
        ),
        
        // subtree: Thin executable wrapper
        .executableTarget(
            name: "subtree",
            dependencies: ["SubtreeLib"]
        ),
        
        // SubtreeLibTests: Unit tests (uses built-in Swift Testing from Swift 6.1)
        .testTarget(
            name: "SubtreeLibTests",
            dependencies: [
                "SubtreeLib"
            ]
        ),
        
        // IntegrationTests: CLI end-to-end tests only (uses built-in Swift Testing from Swift 6.1)
        // Tests the CLI binary via TestHarness without importing SubtreeLib
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "Yams", package: "Yams")
            ]
        )
    ]
)
