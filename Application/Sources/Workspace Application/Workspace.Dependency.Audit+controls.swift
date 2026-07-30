private import Byte_Primitives
private import Byte_Primitives_Standard_Library_Integration
private import GitHub

extension Workspace.Dependency.Audit {
    func controls() async -> Workspace.Dependency.Controls {
        guard let organization = policy.organizations.first else {
            return .init(positive: false, negative: false)
        }
        let declared = Workspace.Repository.Key(
            owner: .init("dependency-audit-control"),
            name: .init("declared")
        )
        let external = Workspace.Repository.Key(
            owner: .init("dependency-audit-external"),
            name: .init("canonical")
        )
        let institute = Workspace.Repository.Key(
            owner: organization.name,
            name: .init("dependency-audit-control")
        )

        async let positive = control(
            organization: organization,
            declared: declared,
            canonical: external,
            ownership: .thirdParty,
            commented: false,
            status: 1
        )
        async let negative = control(
            organization: organization,
            declared: declared,
            canonical: institute,
            ownership: .institute,
            commented: true,
            status: 0
        )
        return await .init(positive: positive, negative: negative)
    }

    private func control(
        organization: Workspace.Inventory.Organization,
        declared: Workspace.Repository.Key,
        canonical: Workspace.Repository.Key,
        ownership: Workspace.Dependency.Ownership,
        commented: Swift.Bool,
        status: Swift.Int32
    ) async -> Swift.Bool {
        let consumer = Workspace.Repository.Key(
            owner: organization.name,
            name: .init("dependency-audit-runtime-control")
        )
        let repository = Workspace.Repository(
            name: consumer.name.underlying,
            url: consumer.url,
            organization: organization.name.underlying,
            layer: organization.layer
        )
        let source =
            (
                commented
                    ? #"// .package(url: "https://github.com/dependency-audit-external/commented.git", branch: "main")"#
                        + "\n"
                    : ""
            )
            + #".package(url: "\#(declared.url)", branch: "main")"#
        let client = Workspace.Dependency.Client(
            repository: { key in
                let resolved: Workspace.Repository.Key
                if key == consumer {
                    resolved = consumer
                } else if key == declared {
                    resolved = canonical
                } else {
                    return .unmeasured(
                        "runtime control received an unexpected repository \(key.identity)"
                    )
                }
                return .available(
                    .init(
                        key: resolved,
                        ownerIsUser: false,
                        visibility: .public,
                        archived: false,
                        disabled: false,
                        defaultBranch: "main"
                    )
                )
            },
            source: { metadata in
                guard metadata.key == consumer else {
                    return .unmeasured(
                        "runtime control received an unexpected source \(metadata.key.identity)"
                    )
                }
                return .available(
                    .init(
                        reference: "main",
                        revision: "runtime-control-revision",
                        manifests: [.init(path: "Package.swift", object: "runtime-control")]
                    )
                )
            },
            content: { key, blob in
                guard key == consumer, blob.object == "runtime-control" else {
                    return .unmeasured("runtime control received unexpected manifest content")
                }
                return .available([Byte](source.utf8))
            }
        )
        let report = await Workspace.Dependency.Audit(
            repositories: [repository],
            policy: policy,
            client: client,
            inventoryReference: "runtime-control",
            inventoryRevision: "runtime-control-revision",
            parser: parser,
            fanout: .init(jobs: 1)
        ).run(controls: .init(positive: true, negative: true))

        return report.status == status
            && report.edges.count == 1
            && report.edges[0].declaredURL == declared.url
            && report.edges[0].canonicalURL == canonical.url
            && report.edges[0].state == .measured
            && report.identities.count == 1
            && report.identities[0].identity == canonical.identity
            && report.identities[0].ownership == ownership
            && report.identities[0].state == .measured
    }
}
