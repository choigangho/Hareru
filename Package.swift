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
        .executable(
            name: "HareruPreview",
            targets: ["HareruPreview"]
        ),
    ],
    targets: [
        .target(
            name: "Hareru",
            path: "Sources/Hareru",
            exclude: [
                "App"
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
        .executableTarget(
            name: "HareruPreview",
            dependencies: ["Hareru"],
            path: "Sources/Hareru/App"
        ),
        .testTarget(
            name: "HareruTests",
            dependencies: ["Hareru"],
            path: "Tests/HareruTests"
        ),
    ]
)
