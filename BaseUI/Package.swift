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
    dependencies: [
        .package(url: "https://github.com/PhanithNY/EasyAnchor.git", branch: "master")
    ],
    targets: [
        .target(
            name: "BaseUI",
            dependencies: ["EasyAnchor"],
            path: "Sources/BaseUI"
        ),
        .testTarget(
            name: "BaseUITests",
            dependencies: ["BaseUI"],
            path: "Tests/BaseUITests"
        ),
    ]
)
