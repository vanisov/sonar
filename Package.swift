// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Sonar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Sonar"),
        .testTarget(name: "SonarTests", dependencies: ["Sonar"]),
    ]
)
