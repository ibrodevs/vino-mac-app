// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Vino",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Vino", targets: ["Vino"])
    ],
    targets: [
        .executableTarget(
            name: "Vino",
            path: "Sources/Vino"
        )
    ],
    swiftLanguageVersions: [.v5]
)
