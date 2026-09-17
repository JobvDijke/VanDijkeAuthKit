// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VanDijkeAuthKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "VanDijkeAuthKit",
            targets: ["VanDijkeAuthKit"]
        ),
    ],
    targets: [
        .target(name: "VanDijkeAuthKit"),
        .testTarget(
            name: "VanDijkeAuthKitTests",
            dependencies: ["VanDijkeAuthKit"]
        ),
    ]
)
