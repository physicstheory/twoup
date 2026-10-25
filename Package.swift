// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TwoUpCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TwoUpCore", targets: ["TwoUpCore"])
    ],
    targets: [
        .target(name: "TwoUpCore"),
        .testTarget(name: "TwoUpCoreTests", dependencies: ["TwoUpCore"])
    ]
)
