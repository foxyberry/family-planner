// swift-tools-version: 6.2
// Source of truth for third-party Swift packages. Bazel reads it through
// rules_swift_package_manager; SwiftPM itself never builds this project.
import PackageDescription

let package = Package(
    name: "FamilyPlanner",
    platforms: [.iOS(.v26)],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            .upToNextMajor(from: "1.23.1")
        ),
    ]
)
