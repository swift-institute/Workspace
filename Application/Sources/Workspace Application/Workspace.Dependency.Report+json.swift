import JSON

extension Workspace.Dependency.Report {
    /// Stable machine-readable output. Arrays are already sorted by the audit,
    /// and object keys are sorted by the renderer.
    public var json: Swift.String {
        let document: JSON = [
            "schemaVersion": 1.json,
            "inventory": [
                "document": "Institute.json".json,
                "reference": inventoryReference.json,
                "revision": inventoryRevision.json,
                "population": subjects.count.json,
                "repositories": subjects.map(\.repository.identity).json,
            ],
            "controls": [
                "positive": controls.positive.json,
                "negative": controls.negative.json,
            ],
            "sanctionedExceptions": sanctioned.map(\.identity).json,
            "repositories": subjects.map { subject in
                [
                    "repository": subject.repository.identity.json,
                    "sourceReference": subject.reference.json,
                    "sourceRevision": subject.revision.json,
                    "status": subject.state.rawValue.json,
                    "reason": subject.reason.json,
                ] as JSON
            }.json,
            "manifests": manifests.map { manifest in
                [
                    "repository": manifest.repository.identity.json,
                    "path": manifest.path.json,
                    "sourceReference": manifest.reference.json,
                    "sourceRevision": manifest.revision.json,
                    "status": manifest.state.rawValue.json,
                    "reason": manifest.reason.json,
                ] as JSON
            }.json,
            "directEdges": edges.map { edge in
                [
                    "repository": edge.repository.identity.json,
                    "manifest": edge.manifest.json,
                    "sourceReference": edge.reference.json,
                    "sourceRevision": edge.revision.json,
                    "line": edge.line.json,
                    "declaredURL": edge.declaredURL.json,
                    "canonicalURL": edge.canonicalURL.json,
                    "identity": edge.identity.json,
                    "status": edge.state.rawValue.json,
                    "reason": edge.reason.json,
                ] as JSON
            }.json,
            "packageIdentities": identities.map { identity in
                [
                    "identity": identity.identity.json,
                    "canonicalURL": identity.canonicalURL.json,
                    "declaredURLs": identity.declaredURLs.json,
                    "ownership": identity.ownership.rawValue.json,
                    "status": identity.state.rawValue.json,
                    "reason": identity.reason.json,
                ] as JSON
            }.json,
            "excludedDeclarations": exclusions.map { exclusion in
                [
                    "repository": exclusion.repository.identity.json,
                    "manifest": exclusion.manifest.json,
                    "sourceReference": exclusion.reference.json,
                    "sourceRevision": exclusion.revision.json,
                    "line": exclusion.line.json,
                    "kind": exclusion.kind.rawValue.json,
                    "value": exclusion.value.json,
                    "reason": exclusion.reason.json,
                ] as JSON
            }.json,
            "transitiveClosure": [
                "status": "not-measured".json,
                "reason": "this run measures direct manifest declarations only".json,
            ],
        ]
        return document.jsonString(pretty: true, sortKeys: true) + "\n"
    }
}
