// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TextPolish",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TextPolish",
            path: "Sources/TextPolish",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("Security"),
            ]
        ),
    ]
)
