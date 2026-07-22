// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "workspace",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "workspace",
            targets: ["workspace"]
        )
    ],
    targets: [
        .executableTarget(
            name: "workspace"
        ),
        .testTarget(
            name: "workspace Tests",
            dependencies: ["workspace"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        ]
}
