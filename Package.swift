// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MiniGraphviz",
    products: [
        .library(
            name: "MiniGraphviz",
            targets: ["MiniGraphviz"]
        ),
    ],
    targets: [
        .target(
            name: "MiniGraphviz"
        ),
        .testTarget(
            name: "MiniGraphvizTests",
            dependencies: ["MiniGraphviz"]
        ),
    ]
)
