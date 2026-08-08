import Testing
private import Byte_Primitives
private import Byte_Primitives_Standard_Library_Integration
private import GitHub
private import JSON
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

    @Test
    func `Repository URLs accept only exact canonical GitHub HTTPS syntax`() {
        let canonical = "https://github.com/swift-foundations/swift-json.git"
        #expect(Workspace.Repository.Key(url: canonical)?.url == canonical)

        let hostile = [
            "http://github.com/swift-foundations/swift-json.git",
            "https://user@github.com/swift-foundations/swift-json.git",
            "https://github.com:443/swift-foundations/swift-json.git",
            "https://github.com/swift-foundations/swift-json.git?ref=main",
            "https://github.com/swift-foundations/swift-json.git#fragment",
            "https://github.com/swift-foundations/swift%2Djson.git",
            "https://github.com/swift%2Dfoundations/swift-json.git",
            "https://github.com/swift-foundations/swift-json.git/extra",
            "https://GitHub.com/swift-foundations/swift-json.git",
        ]
        for url in hostile {
            #expect(Workspace.Repository.Key(url: url) == nil)
        }
    }

    @Test
    func `Repository identity deserialization rejects encoded and structural syntax`() throws {
        let canonical = "swift-foundations/swift-json"
        #expect(Workspace.Repository.Key(identity: canonical)?.identity == canonical)
        #expect(
            try Workspace.Repository.Key.deserialize(canonical.json).identity
                == canonical
        )

        let hostile = [
            "swift-foundations/swift-json/extra",
            "swift%2Dfoundations/swift-json",
            "swift-foundations/swift%2Djson",
            "swift-foundations/swift-json?ref=main",
            "swift-foundations/swift-json#fragment",
            "user@swift-foundations/swift-json",
            "swift-foundations/..",
        ]
        for identity in hostile {
            #expect(Workspace.Repository.Key(identity: identity) == nil)
            #expect(throws: JSON.Error.self) {
                _ = try Workspace.Repository.Key.deserialize(identity.json)
            }
        }
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
        let external = Workspace.Repository.Key(
            owner: .init("vendor"),
            name: .init("external")
        )
        let institute = Workspace.Repository.Key(
            owner: .init("swift-foundations"),
            name: .init("internal")
        )

        let finding = await Workspace.Dependency.Audit(
            repositories: [repository],
            policy: .institute(),
            client: Self.single(
                source:
                    #".package(url: "https://github.com/redirect-control/external.git", branch: "main")"#,
                consumer: key,
                dependency: external,
                ownerIsUser: false
            ),
            inventoryReference: "HEAD",
            inventoryRevision: "finding"
        ).run()
        let clean = await Workspace.Dependency.Audit(
            repositories: [repository],
            policy: .institute(),
            client: Self.single(
                source:
                    #".package(url: "https://github.com/redirect-control/internal.git", branch: "main")"#,
                consumer: key,
                dependency: institute,
                ownerIsUser: false
            ),
            inventoryReference: "HEAD",
            inventoryRevision: "clean"
        ).run()

        #expect(finding.controls.passed)
        #expect(finding.status == 1)
        #expect(finding.identities.map(\.ownership) == [.thirdParty])
        #expect(finding.edges.map(\.canonicalURL) == [external.url])
        #expect(clean.controls.passed)
        #expect(clean.status == 0)
        #expect(clean.identities.map(\.ownership) == [.institute])
        #expect(clean.edges.map(\.canonicalURL) == [institute.url])
    }

    @Test
    func `Path-only declaration makes an otherwise complete report status two`() async {
        let repository = Self.repository("path-only")
        let key = Workspace.Repository.Key(repository: repository)!
        let report = await Workspace.Dependency.Audit(
            repositories: [repository],
            policy: .institute(),
            client: Self.single(
                source: #".package(path: "..")"#,
                consumer: key,
                dependency: key,
                ownerIsUser: false
            ),
            inventoryReference: "HEAD",
            inventoryRevision: "path-only"
        ).run()

        #expect(report.subjects.map(\.state) == [.measured])
        #expect(report.edges.isEmpty)
        #expect(report.identities.isEmpty)
        #expect(report.exclusions.map(\.kind) == [.path])
        #expect(report.status == 2)
    }

    @Test
    func `Registry-only declaration makes an otherwise complete report status two`() async {
        let repository = Self.repository("registry-only")
        let key = Workspace.Repository.Key(repository: repository)!
        let report = await Workspace.Dependency.Audit(
            repositories: [repository],
            policy: .institute(),
            client: Self.single(
                source: #".package(id: "example.library", from: "1.0.0")"#,
                consumer: key,
                dependency: key,
                ownerIsUser: false
            ),
            inventoryReference: "HEAD",
            inventoryRevision: "registry-only"
        ).run()

        #expect(report.subjects.map(\.state) == [.measured])
        #expect(report.edges.isEmpty)
        #expect(report.identities.isEmpty)
        #expect(report.exclusions.map(\.kind) == [.registry])
        #expect(report.status == 2)
    }

    @Test
    func `Human summary names every dependency failure state and reason deterministically`() async {
        let repository = Self.repository("failure-summary")
        let key = Workspace.Repository.Key(repository: repository)!
        let audit = Workspace.Dependency.Audit(
            repositories: [repository],
            policy: .institute(),
            client: Self.failures(consumer: key),
            inventoryReference: "HEAD",
            inventoryRevision: "failure-summary"
        )

        let first = await audit.run()
        let second = await audit.run()
        let summary = first.description

        #expect(summary == second.description)
        for (state, identity, reason) in [
            ("unavailable", "failure-control/unavailable", "fixture unavailable dependency"),
            ("rate-limited", "failure-control/rate-limited", "fixture rate-limited dependency"),
            ("malformed", "failure-control/malformed", "fixture malformed dependency"),
            ("unmeasured", "failure-control/unmeasured", "fixture unmeasured dependency"),
        ] {
            #expect(
                summary.contains(
                    "\(state) edge: swift-foundations/failure-summary/Package.swift:"
                )
            )
            #expect(
                summary.contains(
                    "-> https://github.com/\(identity).git (identity \(identity)) — \(reason)"
                )
            )
            #expect(
                summary.contains(
                    "\(state) identity: \(identity) — \(reason)"
                )
            )
        }
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
        visibility: GitHub.Repository.Visibility = .public
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
                            visibility: .private
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

    private static func failures(
        consumer: Workspace.Repository.Key
    ) -> Workspace.Dependency.Client {
        let source = #"""
            .package(url: "https://github.com/failure-control/unavailable.git", branch: "main"),
            .package(url: "https://github.com/failure-control/rate-limited.git", branch: "main"),
            .package(url: "https://github.com/failure-control/malformed.git", branch: "main"),
            .package(url: "https://github.com/failure-control/unmeasured.git", branch: "main"),
            """#
        return .init(
            repository: { key in
                switch key.identity {
                case consumer.identity:
                    .available(metadata(consumer))
                case "failure-control/unavailable":
                    .unavailable("fixture unavailable dependency")
                case "failure-control/rate-limited":
                    .rateLimited("fixture rate-limited dependency")
                case "failure-control/malformed":
                    .malformed("fixture malformed dependency")
                case "failure-control/unmeasured":
                    .unmeasured("fixture unmeasured dependency")
                default:
                    .unmeasured("unexpected repository \(key.identity)")
                }
            },
            source: { metadata in
                guard metadata.key == consumer else {
                    return .unmeasured("unexpected source \(metadata.key.identity)")
                }
                return .available(
                    .init(
                        reference: "main",
                        revision: "failure-summary-revision",
                        manifests: [.init(path: "Package.swift", object: "manifest")]
                    )
                )
            },
            content: { key, _ in
                guard key == consumer else {
                    return .unmeasured("unexpected content \(key.identity)")
                }
                return .available([Byte](source.utf8))
            }
        )
    }
}
