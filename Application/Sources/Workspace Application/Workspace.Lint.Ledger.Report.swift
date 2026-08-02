public import JSON

extension Workspace.Lint.Ledger {
    /// The complete, deterministically ordered residual compliance ledger.
    public struct Report: Equatable, Sendable, CustomStringConvertible {
        public let packages: [Package]
        public let dispositions: [Disposition]
        public let batches: [Batch]

        public init(
            repositories: [Workspace.Repository],
            report: Workspace.Lint.Report,
            dispositions: [Disposition],
            verifications: [Verification]
        ) throws(Workspace.Error) {
            guard report.scope == .all else {
                throw .configuration("lint ledger requires the complete inventory scope")
            }
            guard report.inventory == repositories.count else {
                throw .configuration(
                    "lint ledger inventory count \(report.inventory) does not match its "
                        + "\(repositories.count) repository records"
                )
            }
            let unmaterialized = Swift.Set(report.unmaterialized)
            guard unmaterialized.count == report.unmaterialized.count else {
                throw .configuration("lint ledger received duplicate unmaterialized rows")
            }
            guard report.considered + unmaterialized.count == repositories.count else {
                throw .configuration(
                    "lint ledger population does not partition into considered and "
                        + "unmaterialized repositories"
                )
            }
            guard report.considered == report.measurements.count else {
                throw .configuration(
                    "lint ledger considered \(report.considered) repositories but received "
                        + "\(report.measurements.count) measurements"
                )
            }
            var dispositionsByRule = [Swift.String: Disposition]()
            for disposition in dispositions {
                guard dispositionsByRule[disposition.rule] == nil else {
                    throw .configuration(
                        "duplicate ledger disposition for rule \(disposition.rule)"
                    )
                }
                dispositionsByRule[disposition.rule] = disposition
            }

            var verificationsByRepository = [Workspace.Repository.Key: Verification]()
            for verification in verifications {
                guard verificationsByRepository[verification.repository] == nil else {
                    throw .configuration(
                        "duplicate ledger verification for \(verification.repository.identity)"
                    )
                }
                verificationsByRepository[verification.repository] = verification
            }

            var measurements = [Workspace.Repository.Key: [Workspace.Lint.Measurement]]()
            for measurement in report.measurements {
                guard let repository = measurement.repository else {
                    throw .configuration(
                        "lint ledger received a measurement without an inventory coordinate"
                    )
                }
                measurements[repository, default: []].append(measurement)
            }

            var packages = [Package]()
            packages.reserveCapacity(repositories.count)
            var inventory = Swift.Set<Workspace.Repository.Key>()
            for repository in repositories {
                guard let key = Workspace.Repository.Key(repository: repository) else {
                    throw .configuration(
                        "ledger cannot resolve repository identity for \(repository.url)"
                    )
                }
                guard inventory.insert(key).inserted else {
                    throw .configuration("duplicate ledger inventory repository \(key.identity)")
                }
                let verification = verificationsByRepository[key]
                let matches = measurements[key] ?? []
                guard matches.count == 1, let measurement = matches.first else {
                    let reason: Swift.String
                    if matches.count > 1 {
                        reason = "sweep returned \(matches.count) measurements for one repository"
                    } else if unmaterialized.contains(key.identity) {
                        reason = "repository is not materialized as a Swift package"
                    } else {
                        reason = "sweep returned no measurement for this inventory repository"
                    }
                    packages.append(
                        .init(
                            repository: key,
                            owner: repository.organization,
                            layer: repository.layer,
                            state: .unmeasured,
                            reason: reason,
                            prerequisite: nil,
                            summary: nil,
                            errors: nil,
                            advisories: [],
                            verification: verification
                        )
                    )
                    continue
                }

                if case .unmeasured(let reason) = measurement.verdict {
                    packages.append(
                        .init(
                            repository: key,
                            owner: repository.organization,
                            layer: repository.layer,
                            state: .unmeasured,
                            reason: reason,
                            prerequisite: measurement.prerequisite,
                            summary: measurement.summary,
                            errors: nil,
                            advisories: [],
                            verification: verification
                        )
                    )
                    continue
                }
                guard
                    let summary = measurement.summary,
                    let findings = measurement.structured
                else {
                    let prerequisite = Workspace.Lint.Prerequisite.sarif
                    packages.append(
                        .init(
                            repository: key,
                            owner: repository.organization,
                            layer: repository.layer,
                            state: .unmeasured,
                            reason: prerequisite.reason,
                            prerequisite: prerequisite,
                            summary: measurement.summary,
                            errors: nil,
                            advisories: [],
                            verification: verification
                        )
                    )
                    continue
                }
                guard summary.violations == findings.count else {
                    packages.append(
                        .init(
                            repository: key,
                            owner: repository.organization,
                            layer: repository.layer,
                            state: .unmeasured,
                            reason:
                                "run summary reports \(summary.violations) findings but structured "
                                + "evidence contains \(findings.count)",
                            prerequisite: nil,
                            summary: summary,
                            errors: nil,
                            advisories: [],
                            verification: verification
                        )
                    )
                    continue
                }

                var advisoryFindings = [Swift.String: [Workspace.Lint.Finding]]()
                for finding in findings where !finding.severity.isError {
                    advisoryFindings[finding.rule, default: []].append(finding)
                }
                let advisories = advisoryFindings.keys.sorted().map { rule in
                    Advisory(
                        rule: rule,
                        findings: advisoryFindings[rule] ?? [],
                        disposition: dispositionsByRule[rule]
                    )
                }
                packages.append(
                    .init(
                        repository: key,
                        owner: repository.organization,
                        layer: repository.layer,
                        state: .measured,
                        reason: nil,
                        prerequisite: nil,
                        summary: summary,
                        errors: findings.filter(\.severity.isError).count,
                        advisories: advisories,
                        verification: verification
                    )
                )
            }

            let unknownVerifications = Swift.Set(verificationsByRepository.keys)
                .subtracting(inventory)
            guard unknownVerifications.isEmpty else {
                throw .configuration(
                    "ledger verification names repositories outside the inventory: "
                        + unknownVerifications.sorted(by: Workspace.Repository.Key.precedes)
                        .map(\.identity).joined(separator: ", ")
                )
            }
            let unknownMeasurements = Swift.Set(measurements.keys).subtracting(inventory)
            guard unknownMeasurements.isEmpty else {
                throw .configuration(
                    "lint ledger measured repositories outside the inventory: "
                        + unknownMeasurements.sorted(by: Workspace.Repository.Key.precedes)
                        .map(\.identity).joined(separator: ", ")
                )
            }
            let identities = Swift.Set(inventory.map(\.identity))
            let unknownUnmaterialized = unmaterialized.subtracting(identities)
            guard unknownUnmaterialized.isEmpty else {
                throw .configuration(
                    "lint ledger names unmaterialized repositories outside the inventory: "
                        + unknownUnmaterialized.sorted().joined(separator: ", ")
                )
            }
            let measuredIdentities = Swift.Set(measurements.keys.map(\.identity))
            let contradictory = unmaterialized.intersection(measuredIdentities)
            guard contradictory.isEmpty else {
                throw .configuration(
                    "lint ledger reports repositories as both measured and unmaterialized: "
                        + contradictory.sorted().joined(separator: ", ")
                )
            }

            self.packages = packages.sorted { lhs, rhs in
                Workspace.Repository.Key.precedes(lhs.repository, rhs.repository)
            }
            self.dispositions = dispositions.sorted { lhs, rhs in
                if lhs.rule != rhs.rule { return lhs.rule < rhs.rule }
                return lhs.issue.identity < rhs.issue.identity
            }
            self.batches = Self.batches(from: self.packages)
        }
    }
}

extension Workspace.Lint.Ledger.Report {
    /// The engine structured-output prerequisite.
    public static let prerequisite = Workspace.Lint.Prerequisite.sarif.issue

    public var measured: [Workspace.Lint.Ledger.Package] {
        packages.filter { $0.state == .measured }
    }

    public var unmeasured: [Workspace.Lint.Ledger.Package] {
        packages.filter { $0.state == .unmeasured }
    }

    public var errors: Swift.Int {
        packages.reduce(0) { $0 + ($1.errors ?? 0) }
    }

    public var advisories: Swift.Int {
        packages.reduce(0) { total, package in
            total + package.advisories.reduce(0) { $0 + $1.findings.count }
        }
    }

    public var unresolved: Swift.Int {
        packages.reduce(0) { total, package in
            total + package.advisories.filter { $0.disposition == nil }.count
        }
    }

    public var blocked: Swift.Bool {
        unmeasured.contains { $0.prerequisite == .sarif }
    }

    /// Exit 2 for incomplete evidence, 1 for measured errors, 0 otherwise.
    public var status: Swift.Int32 {
        if packages.isEmpty || !unmeasured.isEmpty || unresolved > 0 { return 2 }
        return errors > 0 ? 1 : 0
    }

    public var json: Swift.String {
        let document: JSON = [
            "schemaVersion": 1.json,
            "status": statusText.json,
            "prerequisite": [
                "kind": Workspace.Lint.Prerequisite.sarif.token.json,
                "issue": Self.prerequisite.json,
                "state": (blocked ? "blocked" : "satisfied").json,
            ] as JSON,
            "population": [
                "inventory": packages.count.json,
                "reported": packages.count.json,
                "measured": measured.count.json,
                "unmeasured": unmeasured.count.json,
            ] as JSON,
            "summary": [
                "errors": errors.json,
                "advisoryFindings": advisories.json,
                "unresolvedAdvisories": unresolved.json,
            ] as JSON,
            "dispositions": dispositions.map(Self.json).json,
            "packages": packages.map(Self.json).json,
            "batches": batches.map(Self.json).json,
        ]
        return document.jsonString(pretty: true, sortKeys: true) + "\n"
    }

    public var description: Swift.String {
        var lines = [
            "lint residual ledger: \(statusText) — \(packages.count) inventory repositories"
        ]
        for package in packages {
            switch package.state {
            case .unmeasured:
                lines.append(
                    "UNMEASURED  \(package.repository.identity) · owner \(package.owner) · layer "
                        + package.layer.token
                )
                lines.append("            \(package.reason ?? "reason unavailable")")
                if let prerequisite = package.prerequisite {
                    lines.append("  prerequisite: \(prerequisite.token) · \(prerequisite.issue)")
                }
            case .measured:
                lines.append(
                    "MEASURED    \(package.repository.identity) · owner \(package.owner) · layer "
                        + package.layer.token + " · "
                        + "\(package.errors ?? 0) errors · "
                        + "\(package.advisories.reduce(0) { $0 + $1.findings.count }) advisories"
                )
                for advisory in package.advisories {
                    if let disposition = advisory.disposition {
                        lines.append(
                            "  \(advisory.rule) · \(advisory.findings.count) · "
                                + "\(disposition.state.token) · \(disposition.issue.identity)"
                        )
                    } else {
                        lines.append(
                            "  \(advisory.rule) · \(advisory.findings.count) · UNRESOLVED"
                        )
                    }
                }
            }
            if let verification = package.verification {
                lines.append("  verification: \(verification.revision) · \(verification.url)")
            } else {
                lines.append("  verification: unknown")
            }
        }
        if !batches.isEmpty {
            lines.append("")
            lines.append("remediation batches:")
            for batch in batches {
                lines.append(
                    "  \(batch.rule) · \(batch.owner.identity) · \(batch.issue) · "
                        + "\(batch.repositories.count) repositories · \(batch.findings) findings"
                )
                lines.append(
                    "    " + batch.repositories.map(\.identity).joined(separator: ", ")
                )
            }
        }
        lines.append("")
        lines.append(
            "ledger: \(measured.count) measured · \(unmeasured.count) UNMEASURED · "
                + "\(errors) errors · \(advisories) advisory findings · "
                + "\(unresolved) unresolved advisory rows"
        )
        if blocked {
            lines.append("blocked prerequisite: \(Self.prerequisite)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private var statusText: Swift.String {
        if status == 2 { return "incomplete" }
        return status == 1 ? "noncompliant" : "compliant"
    }

    private static func batches(
        from packages: [Workspace.Lint.Ledger.Package]
    ) -> [Workspace.Lint.Ledger.Batch] {
        var groups = [
            Swift.String: (
                rule: Swift.String,
                owner: Workspace.Repository.Key,
                issue: Swift.String,
                repositories: Swift.Set<Workspace.Repository.Key>,
                findings: Swift.Int
            )
        ]()
        for package in packages {
            for advisory in package.advisories {
                guard let disposition = advisory.disposition else { continue }
                let owner = disposition.issue.repository
                let identity = "\(advisory.rule)\u{0}\(owner.identity)"
                var group =
                    groups[identity] ?? (
                        rule: advisory.rule,
                        owner: owner,
                        issue: disposition.issue.identity,
                        repositories: [],
                        findings: 0
                    )
                group.repositories.insert(package.repository)
                group.findings += advisory.findings.count
                groups[identity] = group
            }
        }
        return groups.values.map { group in
            .init(
                rule: group.rule,
                owner: group.owner,
                issue: group.issue,
                repositories: [Workspace.Repository.Key](group.repositories),
                findings: group.findings
            )
        }.sorted { lhs, rhs in
            if lhs.rule != rhs.rule { return lhs.rule < rhs.rule }
            return Workspace.Repository.Key.precedes(lhs.owner, rhs.owner)
        }
    }

    private static func json(_ disposition: Workspace.Lint.Ledger.Disposition) -> JSON {
        [
            "rule": disposition.rule.json,
            "state": disposition.state.token.json,
            "terminal": true.json,
            "issue": disposition.issue.identity.json,
            "owner": disposition.issue.repository.identity.json,
        ]
    }

    private static func json(_ prerequisite: Workspace.Lint.Prerequisite) -> JSON {
        [
            "kind": prerequisite.token.json,
            "issue": prerequisite.issue.json,
        ]
    }

    private static func json(_ finding: Workspace.Lint.Finding) -> JSON {
        [
            "rule": finding.rule.json,
            "severity": finding.severity.token.json,
            "message": finding.message.json,
            "path": finding.path.json,
            "line": finding.line.json,
            "column": finding.column.json,
        ]
    }

    private static func json(_ advisory: Workspace.Lint.Ledger.Advisory) -> JSON {
        let disposition: JSON =
            advisory.disposition.map(Self.json) ?? [
                "state": "unresolved".json,
                "terminal": false.json,
                "issue": JSON.null,
                "owner": JSON.null,
            ]
        return [
            "rule": advisory.rule.json,
            "count": advisory.findings.count.json,
            "disposition": disposition,
            "findings": advisory.findings.map(Self.json).json,
        ]
    }

    private static func json(_ package: Workspace.Lint.Ledger.Package) -> JSON {
        let verification: JSON =
            package.verification.map {
                [
                    "state": "known".json,
                    "revision": $0.revision.json,
                    "url": $0.url.json,
                ] as JSON
            } ?? [
                "state": "unknown".json,
                "revision": JSON.null,
                "url": JSON.null,
            ]
        return [
            "repository": package.repository.identity.json,
            "owner": package.owner.json,
            "layer": Workspace.Layer.serialize(package.layer),
            "state": package.state.token.json,
            "reason": package.reason.json,
            "prerequisite": package.prerequisite.map(Self.json) ?? JSON.null,
            "activeRules": package.summary?.activeRules.json ?? JSON.null,
            "filesLinted": package.summary?.filesLinted.json ?? JSON.null,
            "findings": package.summary?.violations.json ?? JSON.null,
            "errors": package.errors.json,
            "advisories": package.advisories.map(Self.json).json,
            "verification": verification,
        ]
    }

    private static func json(_ batch: Workspace.Lint.Ledger.Batch) -> JSON {
        [
            "rule": batch.rule.json,
            "owner": batch.owner.identity.json,
            "issue": batch.issue.json,
            "repositories": batch.repositories.map(\.identity).json,
            "findings": batch.findings.json,
        ]
    }
}
