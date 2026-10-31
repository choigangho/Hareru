// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hareru",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Hareru",
            targets: ["Hareru"]
        ),
    ],
    targets: [
        .target(
            name: "Hareru",
            path: "Sources/Hareru",
            exclude: [
                "App/HareruApp.swift",
                "Features/Game/.gitkeep",
                "Features/Insights/.gitkeep"
            ],
            sources: [
                "Models",
                "Features",
                "Components",
                "Services"
            ],
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
