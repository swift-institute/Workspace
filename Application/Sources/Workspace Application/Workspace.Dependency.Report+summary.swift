extension Workspace.Dependency.Report: CustomStringConvertible {
    public var description: Swift.String {
        let measured = subjects.count { $0.state == .measured }
        let incomplete = subjects.count - measured
        let external = identities.filter {
            $0.ownership == .personalOwner || $0.ownership == .thirdParty
        }
        let exceptions = identities.filter { $0.ownership == .sanctionedException }
        var lines = [
            "dependency audit: \(subjects.count) repositories from Workspace.json "
                + "(\(inventoryReference) at \(inventoryRevision))",
            "\(measured) measured · \(incomplete) excluded or unmeasured · "
                + "\(manifests.count) manifests",
            "\(edges.count) direct URL edges · \(identities.count) distinct package identities",
            "ownership: \(identities.count { $0.ownership == .institute }) Institute · "
                + "\(identities.count { $0.ownership == .personalOwner }) personal-owner · "
                + "\(identities.count { $0.ownership == .thirdParty }) third-party · "
                + "\(exceptions.count) sanctioned-exception · "
                + "\(identities.count { $0.ownership == .unmeasured }) unmeasured",
            "excluded declarations: \(exclusions.count) · transitive closure: not measured",
        ]

        for identity in external {
            lines.append(
                "  \(identity.ownership.rawValue): \(identity.identity) "
                    + "(\(edges.count { $0.identity == identity.identity }) direct edge(s))"
            )
        }
        for identity in exceptions {
            lines.append(
                "  sanctioned-exception: \(identity.identity) "
                    + "(\(edges.count { $0.identity == identity.identity }) direct edge(s))"
            )
        }
        for subject in subjects where subject.state != .measured {
            lines.append(
                "  \(subject.state.rawValue): \(subject.repository.identity)"
                    + (subject.reason.map { " — \($0)" } ?? "")
            )
        }
        for manifest in manifests where manifest.state != .measured {
            lines.append(
                "  \(manifest.state.rawValue): \(manifest.repository.identity)/\(manifest.path)"
                    + (manifest.reason.map { " — \($0)" } ?? "")
            )
        }
        lines.append(
            status == 0
                ? "dependency audit: passed"
                : "dependency audit: not passing (exit \(status))"
        )
        return lines.joined(separator: "\n")
    }
}
