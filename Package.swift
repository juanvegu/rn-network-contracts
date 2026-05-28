// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NetworkContracts",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "NetworkContracts",
            type: .dynamic,
            targets: ["NetworkContracts"]
        ),
    ],
    targets: [
        .target(
            name: "NetworkContracts",
            path: "ios/Sources/NetworkContracts"
        ),
        .testTarget(
            name: "NetworkContractsTests",
            dependencies: ["NetworkContracts"],
            path: "ios/Tests/NetworkContractsTests"
        ),
    ]
)
