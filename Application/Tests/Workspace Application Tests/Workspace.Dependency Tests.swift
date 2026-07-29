import Testing
private import Byte_Primitives
private import Byte_Primitives_Standard_Library_Integration
private import Tagged_Primitives

@testable import Workspace_Application

extension Workspace.Dependency {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Workspace.Dependency.Test.Unit {
    @Test
    func `Parser preserves URL strings and ignores line and nested block comments`() throws {
        let source = #"""
            let package = Package(
                dependencies: [
                    // .package(url: "https://github.com/commented/line.git", branch: "main"),
                    /*
                     .package(url: "https://github.com/commented/block.git", branch: "main")
                     /* .package(url: "https://github.com/commented/nested.git", branch: "main") */
                     */
                    .package(url: "https://github.com/swift-foundations/swift-json.git", branch: "main"),
                ]
            )
            """#

        let declarations = try Workspace.Dependency.Parser().parse([Byte](source.utf8))

        #expect(
            declarations == [
                .url(
                    "https://github.com/swift-foundations/swift-json.git",
                    line: 8
                )
            ]
        )
    }

    @Test
    func `Parser covers every target kind and hoisted product declarations`() throws {
        let source = #"""
            let hoisted: Target.Dependency = .product(name: "Support", package: "support")
            let package = Package(
                dependencies: [
                    .package(url: "https://github.com/vendor/support.git", branch: "main"),
                ],
                targets: [
                    .target(name: "Library", dependencies: [hoisted]),
                    .testTarget(name: "Tests", dependencies: [hoisted]),
                    .executableTarget(name: "Tool", dependencies: [hoisted]),
                    .macro(name: "Macro", dependencies: [hoisted]),
                    .plugin(name: "Plugin", capability: .buildTool(), dependencies: [hoisted]),
                ]
            )
            """#

        let declarations = try Workspace.Dependency.Parser().parse([Byte](source.utf8))

        #expect(
            declarations == [
                .url("https://github.com/vendor/support.git", line: 4)
            ]
        )
    }

    @Test
    func `Parser reports path registry dynamic and noncanonical declarations explicitly`() throws {
        let source = #"""
            .package(path: ".."),
            .package(id: "example.library", from: "1.0.0"),
            .package(url: endpoint, branch: "main"),
            .package(url: "https://github.com/vendor/no-suffix", branch: "main"),
            """#

        let declarations = try Workspace.Dependency.Parser().parse([Byte](source.utf8))

        #expect(declarations[0] == .path("..", line: 1))
        #expect(declarations[1] == .registry("example.library", line: 2))
        #expect(
            declarations[2]
                == .malformed("package url is not a static string literal", line: 3)
        )
        #expect(
            declarations[3]
                == .url("https://github.com/vendor/no-suffix", line: 4)
        )
    }

    @Test
    func `Manifest population includes nested manifests and Swift variants only`() {
        #expect(Workspace.Dependency.Source.Blob.isManifest("Package.swift"))
        #expect(Workspace.Dependency.Source.Blob.isManifest("Tests/Package.swift"))
        #expect(
            Workspace.Dependency.Source.Blob.isManifest(
                "Nested/Package@swift-6.3.swift"
            )
        )
        #expect(!Workspace.Dependency.Source.Blob.isManifest("Sources/Package.swift.txt"))
        #expect(!Workspace.Dependency.Source.Blob.isManifest("Package@swift-.swift"))
        #expect(!Workspace.Dependency.Source.Blob.isManifest("NotPackage.swift"))
    }
}

extension Workspace.Dependency.Test.Integration {
    @Test
    func `Redirects ownership provenance and all measurement failures are deterministic`() async {
        let consumer = Self.repository("consumer")
        let unavailable = Self.repository("unavailable")
        let limited = Self.repository("limited")
        let malformed = Self.repository("malformed")
        let excluded = Self.repository("archived")
        let unmeasured = Self.repository("unmeasured")
        let repositories = [
            consumer, unavailable, limited, malformed, excluded, unmeasured,
        ]
        let client = Self.client(consumer: Workspace.Repository.Key(repository: consumer)!)
        let audit = Workspace.Dependency.Audit(
            repositories: repositories,
            policy: .institute(),
            client: client,
            sanctioned: [
                Workspace.Repository.Key(
                    owner: .init("apple"),
                    name: .init("swift-crypto")
                )
            ],
            inventoryReference: "HEAD",
            inventoryRevision: "workspace-revision",
            fanout: .init(jobs: 2)
        )

        let first = await audit.run()
        let second = await audit.run()

        #expect(first == second)
        #expect(first.json == second.json)
        #expect(first.controls == .init(positive: true, negative: true))
        #expect(first.subjects.count == 6)
        #expect(first.manifests.map(\.path) == [
            "Package.swift",
            "Package@swift-6.3.swift",
            "Tests/Package.swift",
        ])
        #expect(first.edges.count == 7)
        #expect(first.identities.count == 6)
        #expect(
            first.identities.first { $0.identity == "vendor/renamed" }?.declaredURLs
                == ["https://github.com/old/vendor.git"]
        )
        #expect(
            first.edges.first { $0.declaredURL == "https://github.com/old/vendor.git" }?
                .canonicalURL == "https://github.com/vendor/renamed.git"
        )
        #expect(
            first.identities.first { $0.identity == "coenttb/personal" }?.ownership
                == .personalOwner
        )
        #expect(
            first.identities.first { $0.identity == "apple/swift-crypto" }?.ownership
                == .sanctionedException
        )
        #expect(
            first.identities.first {
                $0.identity == "swift-foundations/swift-numerics"
            }?.ownership == .institute
        )
        #expect(first.exclusions.contains { $0.kind == .path })
        #expect(first.subjects.contains { $0.state == .unavailable })
        #expect(first.subjects.contains { $0.state == .rateLimited })
        #expect(first.subjects.contains { $0.state == .malformed })
        #expect(first.subjects.contains { $0.state == .excluded })
        #expect(first.subjects.contains { $0.state == .unmeasured })
        #expect(first.json.contains(#""transitiveClosure": {"#))
        #expect(first.json.contains(#""status": "not-measured""#))
        #expect(!first.json.contains("restricted/canonical"))
        #expect(first.status == 2)
    }

    @Test
    func `Positive finding and clean negative control produce distinct verdicts`() async {
        let repository = Self.repository("control")
        let key = Workspace.Repository.Key(repository: repository)!

        let finding = await Workspace.Dependency.Audit(
            repositories: [repository],
            policy: .institute(),
            client: Self.single(
                source: #".package(url: "https://github.com/vendor/external.git", branch: "main")"#,
                consumer: key,
                dependency: .init(owner: .init("vendor"), name: .init("external")),
                ownerIsUser: false
            ),
            inventoryReference: "HEAD",
            inventoryRevision: "finding"
        ).run()
        let clean = await Workspace.Dependency.Audit(
            repositories: [repository],
            policy: .institute(),
            client: Self.single(
                source: #".package(url: "https://github.com/swift-foundations/internal.git", branch: "main")"#,
                consumer: key,
                dependency: .init(owner: .init("swift-foundations"), name: .init("internal")),
                ownerIsUser: false
            ),
            inventoryReference: "HEAD",
            inventoryRevision: "clean"
        ).run()

        #expect(finding.status == 1)
        #expect(finding.identities.map(\.ownership) == [.thirdParty])
        #expect(clean.status == 0)
        #expect(clean.identities.map(\.ownership) == [.institute])
    }
}

extension Workspace.Dependency.Test.Integration {
    private static func repository(_ name: Swift.String) -> Workspace.Repository {
        .init(
            name: name,
            url: "https://github.com/swift-foundations/\(name).git",
            organization: "swift-foundations",
            layer: .foundations
        )
    }

    private static func metadata(
        _ key: Workspace.Repository.Key,
        user: Swift.Bool = false,
        archived: Swift.Bool = false,
        visibility: Swift.String = "public"
    ) -> Workspace.Dependency.Metadata {
        .init(
            key: key,
            ownerIsUser: user,
            visibility: visibility,
            archived: archived,
            disabled: false,
            defaultBranch: "main"
        )
    }

    private static func client(
        consumer: Workspace.Repository.Key
    ) -> Workspace.Dependency.Client {
        .init(
            repository: { key in
                switch key.identity {
                case consumer.identity:
                    .available(metadata(key))
                case "swift-foundations/unavailable":
                    .unavailable("fixture unavailable")
                case "swift-foundations/limited":
                    .rateLimited("fixture rate limit")
                case "swift-foundations/malformed", "swift-foundations/unmeasured":
                    .available(metadata(key))
                case "swift-foundations/archived":
                    .available(metadata(key, archived: true))
                case "old/vendor":
                    .available(
                        metadata(
                            .init(owner: .init("vendor"), name: .init("renamed"))
                        )
                    )
                case "coenttb/personal":
                    .available(metadata(key, user: true))
                case "public/restricted":
                    .available(
                        metadata(
                            .init(owner: .init("restricted"), name: .init("canonical")),
                            visibility: "private"
                        )
                    )
                default:
                    .available(metadata(key))
                }
            },
            source: { metadata in
                switch metadata.key.identity {
                case consumer.identity:
                    .available(
                        .init(
                            reference: "main",
                            revision: "consumer-revision",
                            manifests: [
                                .init(path: "Package.swift", object: "root"),
                                .init(path: "Tests/Package.swift", object: "nested"),
                                .init(
                                    path: "Package@swift-6.3.swift",
                                    object: "variant"
                                ),
                            ]
                        )
                    )
                case "swift-foundations/malformed":
                    .malformed("fixture malformed source")
                case "swift-foundations/unmeasured":
                    .unmeasured("fixture unmeasured source")
                default:
                    .unmeasured("unexpected source request")
                }
            },
            content: { _, blob in
                switch blob.object {
                case "root":
                    .available(
                        [Byte](
                            #"""
                            .package(url: "https://github.com/old/vendor.git", branch: "main"),
                            .package(name: "swift-numerics", url: "https://github.com/swift-foundations/swift-numerics.git", branch: "main"),
                            .package(url: "https://github.com/coenttb/personal.git", branch: "main"),
                            .package(url: "https://github.com/apple/swift-crypto.git", branch: "main"),
                            .package(url: "https://github.com/public/restricted.git", branch: "main"),
                            .package(path: ".."),
                            """#.utf8
                        )
                    )
                case "nested":
                    .available(
                        [Byte](
                            #".package(url: "https://github.com/old/vendor.git", branch: "main")"#.utf8
                        )
                    )
                case "variant":
                    .available(
                        [Byte](
                            #".package(url: "https://github.com/swift-foundations/swift-json.git", branch: "main")"#.utf8
                        )
                    )
                default:
                    .unavailable("fixture blob unavailable")
                }
            }
        )
    }

    private static func single(
        source: Swift.String,
        consumer: Workspace.Repository.Key,
        dependency: Workspace.Repository.Key,
        ownerIsUser: Swift.Bool
    ) -> Workspace.Dependency.Client {
        .init(
            repository: { key in
                .available(
                    metadata(
                        key == consumer ? consumer : dependency,
                        user: key == consumer ? false : ownerIsUser
                    )
                )
            },
            source: { _ in
                .available(
                    .init(
                        reference: "main",
                        revision: "source-revision",
                        manifests: [.init(path: "Package.swift", object: "manifest")]
                    )
                )
            },
            content: { _, _ in .available([Byte](source.utf8)) }
        )
    }
}
