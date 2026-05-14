// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DiskUsageVisualizer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DiskUsageVisualizer",
            path: "Sources/DiskUsageVisualizer",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
