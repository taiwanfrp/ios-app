// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TaiwanFRP",
    platforms: [
        .iOS(.v26),
        .macOS(.v14),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "TaiwanFRP",
            targets: ["TaiwanFRP"]
        ),
    ],
    targets: [
        .target(
            name: "TaiwanFRP"
        ),
    ]
)
