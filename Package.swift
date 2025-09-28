// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Umbreon",
    defaultLocalization: "en",
    platforms: [ .iOS(.v18), .macOS(.v15) ],
    products: [
        .library(name: "UmbreonAppUI", targets: [ "UmbreonAppUI" ]),
        .library(name: "UmbreonCore", targets: [ "UmbreonCore" ]),
        .library(name: "UmbreonPersistence", targets: [ "UmbreonPersistence" ]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/lucka-me/sphere-geometry-swift.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/mapbox/mapbox-maps-ios.git",
            .upToNextMajor(from: "11.15.1")
        ),
        .package(
            url: "https://github.com/mapbox/turf-swift.git",
            exact: "4.0.0"
        ),
        .package(
            url: "https://github.com/weichsel/ZIPFoundation.git",
            .upToNextMajor(from: "0.9.19")
        ),
    ],
    targets: [
        .target(
            name: "UmbreonAppUI",
            dependencies: [
                .target(name: "UmbreonCore"),
                .product(
                    name: "MapboxMaps",
                    package: "mapbox-maps-ios",
                    condition: .when(platforms: [ .iOS ])
                ),
            ],
            resources: [
                .process("Resources/Localizable.xcstrings"),
            ]
        ),
        .target(
            name: "UmbreonCore",
            dependencies: [
                .product(name: "SphereGeometry", package: "sphere-geometry-swift"),
                .product(name: "Turf", package: "turf-swift"),
            ],
            resources: [
                .copy("Resources/Generated/regions.db"),
                .process("Resources/Generated/regions.xcstrings"),
                .process("Resources/Glossary.xcstrings"),
                .process("Resources/Localizable.xcstrings"),
            ]
        ),
        .target(
            name: "UmbreonPersistence",
            dependencies: [
                .target(name: "UmbreonCore"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            resources: [
                .copy("Resources/Generated/covers"),
                .copy("Resources/Generated/cover-index.json"),
            ]
        ),
    ],
    swiftLanguageModes: [ .v6 ],
)
