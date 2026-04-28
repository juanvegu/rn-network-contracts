// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScotiaRNNetworkContracts",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "ScotiaRNNetworkContracts",
            targets: ["ScotiaRNNetworkContracts"]
        )
    ],
    targets: [
        .target(
            name: "ScotiaRNNetworkContracts",
            path: "Sources/ScotiaRNNetworkContracts"
        )
    ]
)
