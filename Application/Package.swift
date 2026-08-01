// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "workspace",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "Build Coordinator",
            targets: ["Build Coordinator"]
        ),
        .library(
            name: "Skill Validation",
            targets: ["Skill Validation"]
        ),
        .library(
            name: "Workspace Application",
            targets: ["Workspace Application"]
        ),
        .executable(
            name: "workspace",
            targets: ["Workspace CLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-foundations/swift-arguments.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-environment.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-file-system.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-github.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-github-http.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-git.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-json.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-package-manager.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-posix.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-process.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-xcode.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-3986.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-4648.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-byte-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-spm-standard.git", branch: "main"),
        .package(
            url: "https://github.com/swift-primitives/swift-standard-library-extensions.git",
            branch: "main"
        )
    ],
    targets: [
        .target(
            name: "Build Coordinator",
            dependencies: [
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "POSIX Kernel Lock", package: "swift-posix"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Skill Validation"
        ),
        .target(
            name: "Workspace Application",
            dependencies: [
                "Build Coordinator",
                "Skill Validation",
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "GitHub", package: "swift-github"),
                .product(name: "GitHub HTTP", package: "swift-github-http"),
                .product(name: "Git", package: "swift-git"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Package Manager", package: "swift-package-manager"),
                .product(name: "POSIX Kernel Process", package: "swift-posix"),
                .product(name: "Process", package: "swift-process"),
                .product(name: "RFC 3986", package: "swift-rfc-3986"),
                .product(name: "RFC 4648", package: "swift-rfc-4648"),
                .product(name: "Byte Primitives", package: "swift-byte-primitives"),
                .product(name: "Byte Primitives Standard Library Integration", package: "swift-byte-primitives"),
                .product(name: "Xcode Scheme", package: "swift-xcode"),
                .product(name: "Xcode Workspace", package: "swift-xcode")
            ]
        ),
        .executableTarget(
            name: "Workspace CLI",
            dependencies: [
                "Build Coordinator",
                "Workspace Application",
                .product(name: "Command", package: "swift-arguments")
            ]
        ),
        .testTarget(
            name: "Skill Validation Tests",
            dependencies: [
                "Skill Validation",
            ],
            path: "Tests/Skill Validation Tests"
        ),
        .testTarget(
            name: "Workspace Application Tests",
            dependencies: [
                "Build Coordinator",
                "Skill Validation",
                "Workspace Application",
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "GitHub", package: "swift-github"),
                .product(name: "GitHub HTTP", package: "swift-github-http"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "SPM Standard", package: "swift-spm-standard"),
                .product(name: "Byte Primitives", package: "swift-byte-primitives"),
                .product(name: "Byte Primitives Standard Library Integration", package: "swift-byte-primitives"),
                .product(
                    name: "Standard Library Extensions",
                    package: "swift-standard-library-extensions"
                ),
            ],
            path: "Tests/Workspace Application Tests"
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
