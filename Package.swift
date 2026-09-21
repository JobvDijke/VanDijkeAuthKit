// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GewonekipAuthKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "GewonekipAuthKit",
            targets: ["GewonekipAuthKit"]
        ),
    ],
    targets: [
        .target(name: "GewonekipAuthKit"),
        .testTarget(
            name: "GewonekipAuthKitTests",
            dependencies: ["GewonekipAuthKit"]
        ),
    ]
)
