// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BocaSample",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BocaSample",
            targets: ["BocaSample"]
        ),
    ],
    targets: [
        .target(
            name: "BocaSample",
            path: ".",
            exclude: [
                "App/BocaSampleApp.swift"
            ],
            sources: [
                "Models",
                "Services",
                "Views"
            ],
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
