// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetworkContracts",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "NetworkContracts",
            targets: ["NetworkContracts"]
        )
    ],
    targets: [
        .target(
            name: "NetworkContracts",
            path: "Sources/NetworkContracts"
        )
    ]
)
