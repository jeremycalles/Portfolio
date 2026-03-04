// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PortfolioCore",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(name: "PortfolioCore", targets: ["PortfolioCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "PortfolioCore",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                "SwiftSoup"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "PortfolioCoreTests",
            dependencies: ["PortfolioCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
