public import JSON

extension Workspace.Verification {
    /// The content-addressed receipt one verification run emits.
    ///
    /// Conforms to ``Workspace/Receipt/Sealed`` — the module's one
    /// canonicalization-and-digest discipline (issue #83 Part 1) — so
    /// `.canonical` and `.digest` are supplied, not reimplemented
    /// here. Sorted keys, no volatile ordering, no machine paths: the
    /// digest over the canonical serialization freezes the observation.
    /// `version`/`kind` are this schema's own identity, not the subject's;
    /// a schema change bumps `version` rather than silently reshaping a
    /// receipt a consumer already parses.
    public struct Receipt: Equatable, Sendable, Workspace.Receipt.Sealed {
        public let version: Swift.Int
        public let kind: Swift.String
        public let subject: Subject
        public let inventoryDigest: Inventory.Digest
        public let layer: Workspace.Layer
        public let workspaceRevision: Swift.String
        public let policyRevision: Swift.String
        public let environment: Environment
        public let requestedOperations: [Operation.Kind]
        public let operations: [Operation.Result]
        public let platform: Platform
        public let requiredGates: [Gate]
        public let verdict: Verdict

        public init(
            version: Swift.Int = 1,
            kind: Swift.String = "workspace-verification",
            subject: Subject,
            inventoryDigest: Inventory.Digest,
            layer: Workspace.Layer,
            workspaceRevision: Swift.String,
            policyRevision: Swift.String,
            environment: Environment,
            requestedOperations: [Operation.Kind],
            operations: [Operation.Result],
            platform: Platform,
            requiredGates: [Gate],
            verdict: Verdict
        ) {
            self.version = version
            self.kind = kind
            self.subject = subject
            self.inventoryDigest = inventoryDigest
            self.layer = layer
            self.workspaceRevision = workspaceRevision
            self.policyRevision = policyRevision
            self.environment = environment
            self.requestedOperations = requestedOperations
            self.operations = operations
            self.platform = platform
            self.requiredGates = requiredGates
            self.verdict = verdict
        }

        public static func serialize(_ value: Self) -> JSON {
            var members: [(Swift.String, JSON)] = [
                ("version", value.version.json),
                ("kind", value.kind.json),
                ("subject", value.subject.json),
                ("inventoryDigest", value.inventoryDigest.token.json),
                ("layer", value.layer.json),
                ("workspaceRevision", value.workspaceRevision.json),
                ("policyRevision", value.policyRevision.json),
                ("environment", value.environment.json),
                ("requestedOperations", value.requestedOperations.json),
                ("operations", value.operations.json),
                ("platform", value.platform.json),
                ("requiredGates", value.requiredGates.json),
                ("verdict", value.verdict.json),
            ]
            // Present exactly when nothing was measured; absent — not null,
            // not empty — when it was, so a measured receipt's canonical
            // bytes are identical to what this schema produced before the
            // cause existed, and its digest is unchanged.
            if let cause = value.inventoryDigest.cause {
                members.append(("inventoryDigestCause", cause.json))
            }
            return .object(members)
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let version = object["version"] else { throw .missingKey("version") }
            guard let kind = object["kind"] else { throw .missingKey("kind") }
            guard let subject = object["subject"] else { throw .missingKey("subject") }
            guard let inventoryDigestToken = object["inventoryDigest"] else {
                throw .missingKey("inventoryDigest")
            }
            let inventoryDigestCause: Swift.String?
            if let value = object["inventoryDigestCause"], value != .null {
                inventoryDigestCause = try Swift.String(json: value)
            } else {
                inventoryDigestCause = nil
            }
            let token = try Swift.String(json: inventoryDigestToken)
            let inventoryDigest: Workspace.Verification.Inventory.Digest
            do throws(Workspace.Verification.Inventory.Digest.Error) {
                inventoryDigest = try .init(token: token, cause: inventoryDigestCause)
            } catch {
                throw .typeMismatch(expected: "a valid inventory digest", got: "\(error)")
            }
            guard let layer = object["layer"] else { throw .missingKey("layer") }
            guard let workspaceRevision = object["workspaceRevision"] else {
                throw .missingKey("workspaceRevision")
            }
            guard let policyRevision = object["policyRevision"] else {
                throw .missingKey("policyRevision")
            }
            guard let environment = object["environment"] else { throw .missingKey("environment") }
            guard let requestedOperations = object["requestedOperations"] else {
                throw .missingKey("requestedOperations")
            }
            guard let operations = object["operations"] else { throw .missingKey("operations") }
            guard let platform = object["platform"] else { throw .missingKey("platform") }
            guard let requiredGates = object["requiredGates"] else { throw .missingKey("requiredGates") }
            guard let verdict = object["verdict"] else { throw .missingKey("verdict") }
            return try Self(
                version: Swift.Int(json: version),
                kind: Swift.String(json: kind),
                subject: Subject(json: subject),
                inventoryDigest: inventoryDigest,
                layer: Workspace.Layer(json: layer),
                workspaceRevision: Swift.String(json: workspaceRevision),
                policyRevision: Swift.String(json: policyRevision),
                environment: Environment(json: environment),
                requestedOperations: [Operation.Kind](json: requestedOperations),
                operations: [Operation.Result](json: operations),
                platform: Platform(json: platform),
                requiredGates: [Gate](json: requiredGates),
                verdict: Verdict(json: verdict)
            )
        }
    }
}
