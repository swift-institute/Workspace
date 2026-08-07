public import JSON

extension Workspace.Coherence {
    /// The population control: a build that silently selected less than
    /// the roster must never report success — the `UNMEASURED` doctrine
    /// applied to the composed graph.
    ///
    /// `inventoryCount` is the whole inventory (`Institute.json`);
    /// `materializedCount` is what this run's selection actually named.
    /// For a canonical run (no local override in effect) the two must
    /// agree — a narrowed run is expected to disagree, and is marked
    /// non-canonical elsewhere in the receipt rather than failing here.
    /// `expectedTargetCount` is read from the selected manifests before
    /// building (the same read the stale-scheme graph check already
    /// performs); `builtTargetCount` is that same count when the build
    /// stage exits zero, or `0` otherwise. A mismatch between them would
    /// mean the graph stage's own re-render-and-compare gate had already
    /// failed to catch a shrunk scheme — defence in depth, not a second
    /// independent measurement.
    public struct Population: Equatable, Sendable, JSON.Serializable {
        public let inventoryCount: Swift.Int
        public let materializedCount: Swift.Int
        public let builtTargetCount: Swift.Int
        public let expectedTargetCount: Swift.Int

        public init(
            inventoryCount: Swift.Int,
            materializedCount: Swift.Int,
            builtTargetCount: Swift.Int,
            expectedTargetCount: Swift.Int
        ) {
            self.inventoryCount = inventoryCount
            self.materializedCount = materializedCount
            self.builtTargetCount = builtTargetCount
            self.expectedTargetCount = expectedTargetCount
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "inventoryCount": value.inventoryCount.json,
                "materializedCount": value.materializedCount.json,
                "builtTargetCount": value.builtTargetCount.json,
                "expectedTargetCount": value.expectedTargetCount.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let inventoryCount = object["inventoryCount"] else {
                throw .missingKey("inventoryCount")
            }
            guard let materializedCount = object["materializedCount"] else {
                throw .missingKey("materializedCount")
            }
            guard let builtTargetCount = object["builtTargetCount"] else {
                throw .missingKey("builtTargetCount")
            }
            guard let expectedTargetCount = object["expectedTargetCount"] else {
                throw .missingKey("expectedTargetCount")
            }
            return try Self(
                inventoryCount: Swift.Int(json: inventoryCount),
                materializedCount: Swift.Int(json: materializedCount),
                builtTargetCount: Swift.Int(json: builtTargetCount),
                expectedTargetCount: Swift.Int(json: expectedTargetCount)
            )
        }
    }
}
