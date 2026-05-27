// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PushCRM",
    platforms: [
        .iOS(.v13),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "PushCRM",
            targets: ["PushCRM"]
        )
    ],
    targets: [
        .target(
            name: "PushCRM",
            path: "Sources/PushCRM",
            swiftSettings: [
                .define("PUSHCRM_SPM")
            ]
        ),
        .testTarget(
            name: "PushCRMTests",
            dependencies: ["PushCRM"],
            path: "Tests/PushCRMTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
