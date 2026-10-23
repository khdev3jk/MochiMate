// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MochiMate",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MochiMate",
            path: "Sources/MochiMate",
            resources: [.copy("Resources/Sprites"), .copy("Resources/Content")]
        ),
        .testTarget(name: "MochiMateTests", dependencies: ["MochiMate"], path: "Tests/MochiMateTests"),
        // Renders the character sprite sheets into Sources/MochiMate/Resources/Sprites.
        .executableTarget(name: "SpriteGen", path: "Sources/SpriteGen")
    ]
)
