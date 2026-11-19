// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DDEVKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DDEVKit", targets: ["DDEVKit"])
    ],
    targets: [
        .target(name: "DDEVKit"),
        .testTarget(
            name: "DDEVKitTests",
            dependencies: ["DDEVKit"],
            resources: [.copy("Fixtures")]
        )
    ]
)
