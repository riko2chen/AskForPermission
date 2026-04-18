// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AskForPermission",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "AskForPermission",
            targets: ["AskForPermission"]
        ),
    ],
    targets: [
        .target(
            name: "AskForPermission",
            path: "Sources/AskForPermission"
        ),
        .testTarget(
            name: "AskForPermissionTests",
            dependencies: ["AskForPermission"],
            path: "Tests/AskForPermissionTests"
        ),
    ]
)
