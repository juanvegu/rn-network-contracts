// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "iOSNetworkContract",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "iOSNetworkContract",
            type: .dynamic,
            targets: ["iOSNetworkContract"]
        ),
    ],
    targets: [
        .target(
            name: "iOSNetworkContract",
            path: "ios/Sources/iOSNetworkContract"
        ),
        .testTarget(
            name: "iOSNetworkContractTests",
            dependencies: ["iOSNetworkContract"],
            path: "ios/Tests/iOSNetworkContractTests"
        ),
    ]
)
