// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BaseUI",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "BaseUI", targets: ["BaseUI"])
    ],
    targets: [
        .target(
            name: "BaseUI",
            path: "Sources/BaseUI"
        ),
        .testTarget(
            name: "BaseUITests",
            dependencies: ["BaseUI"],
            path: "Tests/BaseUITests"
        ),
    ]
)
