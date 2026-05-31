// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "WaterVoiceCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "WaterVoiceCore", targets: ["WaterVoiceCore"]),
    ],
    targets: [
        .target(name: "WaterVoiceCore"),
        .testTarget(
            name: "WaterVoiceCoreTests",
            dependencies: ["WaterVoiceCore"]
        ),
    ]
)
