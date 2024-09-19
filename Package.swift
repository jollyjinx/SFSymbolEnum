// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "SFSymbolEnum",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "SFSymbolEnum", targets: ["SFSymbolEnum"])
    ],
    targets: [
        .target(name: "SFSymbolEnum")
    ]
)
