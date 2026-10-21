// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SlackPolish",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SlackPolish",
            path: "Sources/SlackPolish",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("Security"),
            ]
        ),
    ]
)
