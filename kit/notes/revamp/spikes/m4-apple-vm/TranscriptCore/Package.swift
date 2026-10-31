// swift-tools-version:5.9
// Portable logic for the spike: no Apple frameworks, so it builds and tests on Linux and macOS.
import PackageDescription

let package = Package(
    name: "TranscriptCore",
    products: [.library(name: "TranscriptCore", targets: ["TranscriptCore"])],
    targets: [
        .target(name: "TranscriptCore"),
        .testTarget(name: "TranscriptCoreTests", dependencies: ["TranscriptCore"]),
    ]
)
