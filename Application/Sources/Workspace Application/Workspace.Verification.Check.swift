extension Workspace.Verification {
    /// `institute verification check`: independently re-parses a sealed
    /// receipt and reports whether it is internally consistent, without
    /// mutating anything and without trusting the producer's own claims.
    ///
    /// Acceptance predicate (Task 2-01): "a validator that independently
    /// parses, canonicalizes, and re-digests the receipt," operating
    /// "independently of producer output ordering." Parsing is
    /// ``Workspace/Verification/Receipt/deserialize(_:)`` (JSON-key order
    /// never matters to it); canonicalization and digesting are
    /// ``Workspace/Receipt/Sealed``'s own members, computed fresh from the
    /// *deserialized* value rather than trusted from the bytes on disk —
    /// so a byte-for-byte reordering of an otherwise-identical receipt
    /// re-digests identically, and one tampered byte changes the digest,
    /// exactly the positive controls this task specifies.
    public enum Check {}
}

extension Workspace.Verification.Check {
    /// All diagnostics found; empty means consistent. Never mutates the
    /// receipt or reruns any operation — a positive result is a report on
    /// the sealed facts, never a repeat measurement.
    public static func diagnostics(for receipt: Workspace.Verification.Receipt) -> [Swift.String] {
        var diagnostics: [Swift.String] = []

        if receipt.version != 1 {
            diagnostics.append("unsupported schema version \(receipt.version); this validator knows 1")
        }

        if receipt.requestedOperations.isEmpty {
            diagnostics.append("requestedOperations is empty; a receipt with nothing requested "
                + "should never have been sealed")
        }

        if !receipt.operations.contains(where: { $0.outcome.isExecuted }) {
            diagnostics.append("no operation reached a real outcome; a receipt attesting nothing was "
                + "measured should never have been sealed")
        }

        // Every gate names an operation kind this receipt actually recorded
        // at least one result for.
        let recordedKinds = Swift.Set(receipt.operations.map(\.operation))
        for gate in receipt.requiredGates {
            guard let kind = Workspace.Verification.Operation.Kind(rawValue: gate.name) else {
                diagnostics.append("required gate \(gate.name) is not a recognised operation kind")
                continue
            }
            if !recordedKinds.contains(kind) {
                diagnostics.append(
                    "required gate \(gate.name) references an operation this receipt never recorded"
                )
            }
        }

        switch receipt.verdict {
        case .verified:
            if receipt.subject.dirty {
                diagnostics.append("verdict is verified but subject.dirty is true")
            }
            if receipt.subject.claimedHead != receipt.subject.observedHead {
                diagnostics.append(
                    "verdict is verified but claimedHead \(receipt.subject.claimedHead) does not "
                        + "match observedHead \(receipt.subject.observedHead)"
                )
            }
            for gate in receipt.requiredGates where !gate.satisfied {
                diagnostics.append("verdict is verified but required gate \(gate.name) is unsatisfied")
            }
            for result in receipt.operations where !result.outcome.isSatisfying {
                diagnostics.append(
                    "verdict is verified but operation \(result.operation.rawValue)"
                        + (result.subpath.map { " (\($0))" } ?? "")
                        + " did not reach a satisfying outcome"
                )
            }
        case .unverified:
            break
        }

        // Defense in depth: the producer already refuses to seal unsafe
        // content (Task 2-01 requirement 5); the validator re-checks
        // independently rather than trusting that refusal held.
        for result in receipt.operations {
            if let evidence = result.compileEvidence,
                let reason = Workspace.Verification.Redaction.diagnose(evidence)
            {
                diagnostics.append(
                    "operation \(result.operation.rawValue) compileEvidence \(reason)"
                )
            }
            for finding in result.findings {
                if let reason = Workspace.Verification.Redaction.diagnose(finding) {
                    diagnostics.append("operation \(result.operation.rawValue) finding \(reason)")
                }
            }
        }

        return diagnostics
    }
}
