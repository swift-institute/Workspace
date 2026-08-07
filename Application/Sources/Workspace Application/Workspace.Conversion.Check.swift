private import File_System
private import Tagged_Primitives

extension Workspace.Conversion {
    /// `institute conversion check <path>`: re-reads a receipt and reports,
    /// without mutating anything, whether it is internally and
    /// historically consistent. Never mutates the receipt or the checkout;
    /// a positive result is a report, not a repair.
    public enum Check {}
}

extension Workspace.Conversion.Check {
    /// Whether a git object still exists in `repository`'s object store —
    /// `git cat-file -e <digest>^{blob}`. Swallows a non-zero exit as
    /// `false` rather than throwing: a missing blob is exactly the
    /// condition this check reports, not a process failure.
    static func realResolves(
        _ root: Workspace.Root,
        _ repository: Workspace.Repository,
        _ digest: Swift.String
    ) -> Swift.Bool {
        guard let location = try? root.materialization(for: repository) else { return false }
        return (try? Workspace.Doctor.spawn(
            "git",
            arguments: ["-C", location.description, "cat-file", "-e", "\(digest)^{blob}"]
        )) != nil
    }
}

extension Workspace.Conversion.Check {
    /// Reconstructs the minimal ``Workspace/Repository`` a cohort record
    /// carries enough of to resolve a materialized checkout.
    static func repository(for entry: Workspace.Conversion.Repository) -> Workspace.Repository {
        .init(
            name: entry.coordinate.name.underlying,
            url: entry.cloneURL,
            organization: entry.coordinate.owner.underlying,
            layer: entry.layer
        )
    }

    /// All diagnostics found; empty means consistent. `resolves` is
    /// injected — real default spawns `git`, so a test can substitute a
    /// fixture answer without a real object store.
    public static func diagnostics(
        for receipt: Workspace.Conversion.Receipt,
        root: Workspace.Root,
        resolves: (
            @Sendable (Workspace.Root, Workspace.Repository, Swift.String) -> Swift.Bool
        )? = nil
    ) -> [Swift.String] {
        let resolves = resolves ?? Self.realResolves
        var diagnostics: [Swift.String] = []

        let cohortByCoordinate = Swift.Dictionary(
            uniqueKeysWithValues: receipt.cohort.map { ($0.coordinate, $0) }
        )

        // Every recorded blob digest still resolves against its repository.
        for page in receipt.pages {
            guard let entry = cohortByCoordinate[page.coordinate] else {
                diagnostics.append(
                    "page \(page.coordinate.identity) \(page.path) names a coordinate outside cohort"
                )
                continue
            }
            let repository = Self.repository(for: entry)
            if !resolves(root, repository, page.preConversionBlob) {
                diagnostics.append(
                    "page \(page.coordinate.identity) \(page.path): preConversionBlob "
                        + "\(page.preConversionBlob) does not resolve"
                )
            }
            if let postConversionBlob = page.postConversionBlob,
                !resolves(root, repository, postConversionBlob)
            {
                diagnostics.append(
                    "page \(page.coordinate.identity) \(page.path): postConversionBlob "
                        + "\(postConversionBlob) does not resolve"
                )
            }
        }

        // The evaluationCohort derivation is total: every cohort repository
        // has a readme page record to derive an arm entry from.
        let readmeCoordinates = Swift.Set(
            receipt.pages.filter { $0.kind == .readme }.map(\.coordinate)
        )
        for entry in receipt.cohort where !readmeCoordinates.contains(entry.coordinate) {
            diagnostics.append(
                "cohort repository \(entry.coordinate.identity) has no readme page record; "
                    + "the evaluationCohort derivation is not total"
            )
        }

        guard let evaluation = receipt.evaluation else { return diagnostics }

        // No trial references a repository outside the cohort.
        for trial in evaluation.trials where cohortByCoordinate[trial.coordinate] == nil {
            diagnostics.append(
                "trial \(trial.trialIdentifier) references \(trial.coordinate.identity), "
                    + "which is outside the cohort"
            )
        }

        // Every trial's readmeBlob equals the arm blob its arm field names.
        let readmePages = Swift.Dictionary(
            uniqueKeysWithValues: receipt.pages
                .filter { $0.kind == .readme }
                .map { ($0.coordinate, $0) }
        )
        for trial in evaluation.trials {
            guard let page = readmePages[trial.coordinate] else { continue }
            let expected: Swift.String? =
                switch trial.arm {
                case .legacy: page.preConversionBlob
                case .converted: page.postConversionBlob
                }
            guard let expected else {
                diagnostics.append(
                    "trial \(trial.trialIdentifier): arm \(trial.arm.rawValue) has no recorded "
                        + "blob for \(trial.coordinate.identity) to compare against"
                )
                continue
            }
            if trial.readmeBlob != expected {
                diagnostics.append(
                    "trial \(trial.trialIdentifier): readmeBlob \(trial.readmeBlob) does not "
                        + "match arm \(trial.arm.rawValue)'s recorded blob \(expected)"
                )
            }
        }

        // pairCount equals the number of scored pairs — pairs formed by
        // repetition within each (coordinate, template) cell (protocol §4);
        // approximated here as the lesser of the two arms' trial counts per
        // cell, summed across cells.
        var cells: [Swift.String: (legacy: Swift.Int, converted: Swift.Int)] = [:]
        for trial in evaluation.trials {
            let key = "\(trial.coordinate.identity)#\(trial.template)"
            var counts = cells[key] ?? (0, 0)
            switch trial.arm {
            case .legacy: counts.legacy += 1
            case .converted: counts.converted += 1
            }
            cells[key] = counts
        }
        let derivedPairCount = cells.values.reduce(0) { $0 + Swift.min($1.legacy, $1.converted) }
        if derivedPairCount != evaluation.summary.pairCount {
            diagnostics.append(
                "summary.pairCount \(evaluation.summary.pairCount) does not match the "
                    + "\(derivedPairCount) pairs derivable from trials"
            )
        }

        // decision is invalid whenever the unmeasured fraction exceeds 0.10
        // (protocol §4).
        let totalPairs = evaluation.summary.pairCount + evaluation.summary.unmeasured
        if totalPairs > 0 {
            let fraction = Swift.Double(evaluation.summary.unmeasured) / Swift.Double(totalPairs)
            if fraction > 0.10, evaluation.summary.decision != .invalid {
                diagnostics.append(
                    "unmeasured fraction \(fraction) exceeds 0.10 but decision is "
                        + "\(evaluation.summary.decision.rawValue), not invalid (protocol §4)"
                )
            }
        }

        // decision is invalid whenever protocolFreezeBlob differs from the
        // instrument's protocolBlob (protocol §0).
        if evaluation.protocolFreezeBlob != receipt.instrument.protocolBlob,
            evaluation.summary.decision != .invalid
        {
            diagnostics.append(
                "evaluation.protocolFreezeBlob \(evaluation.protocolFreezeBlob) differs from "
                    + "instrument.protocolBlob \(receipt.instrument.protocolBlob) but decision is "
                    + "\(evaluation.summary.decision.rawValue), not invalid (protocol §0)"
            )
        }

        return diagnostics
    }
}
