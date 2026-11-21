// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PassbyCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "PassbyCore", targets: ["PassbyCore"])],
    targets: [
        .target(name: "PassbyCore"),
        .testTarget(name: "PassbyCoreTests", dependencies: ["PassbyCore"]),
    ]
)
