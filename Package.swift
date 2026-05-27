// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PushCRM",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "PushCRM", targets: ["PushCRM"])
    ],
    targets: [
        .target(name: "PushCRM", path: "Sources/PushCRM"),
        .testTarget(name: "PushCRMTests", dependencies: ["PushCRM"], path: "Tests/PushCRMTests")
    ]
)
