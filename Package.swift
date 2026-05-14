// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacMenuToolbar",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "CSMC",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "MacMenuToolbar",
            dependencies: ["CSMC"],
            resources: [.process("Resources")]
        )
    ]
)
