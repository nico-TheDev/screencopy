// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ScreencopyKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ScreencopyCore", targets: ["ScreencopyCore"]),
        .library(name: "ScreencopyCapture", targets: ["ScreencopyCapture"]),
        .library(name: "ScreencopyRecognition", targets: ["ScreencopyRecognition"]),
    ],
    targets: [
        .target(name: "ScreencopyCore"),
        .target(name: "ScreencopyCapture", dependencies: ["ScreencopyCore"]),
        .target(name: "ScreencopyRecognition", dependencies: ["ScreencopyCore"]),
        .testTarget(name: "ScreencopyCoreTests", dependencies: ["ScreencopyCore"]),
        .testTarget(name: "ScreencopyCaptureTests", dependencies: ["ScreencopyCapture"]),
        .testTarget(name: "ScreencopyRecognitionTests", dependencies: ["ScreencopyRecognition"]),
    ]
)
