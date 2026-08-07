public import JSON

extension Workspace.Coherence {
    /// A run's overall verdict.
    ///
    /// `unmeasured` covers every case where the composed graph was never
    /// actually put to the test — a stage before `build` failed, or `build`
    /// succeeded but the population control found the measured population
    /// short of what was expected. `incoherent` is reserved for the one
    /// stage that *does* produce comparable evidence about the graph itself:
    /// a `build`-stage compile failure, which carries a mechanical
    /// attribution. A run reporting `unmeasured` is never described as
    /// passing, exactly as ``Workspace/Doctor/Report`` never calls an
    /// unmeasured check clean.
    public enum Verdict: Swift.String, Equatable, Sendable, JSON.Serializable {
        case coherent
        case incoherent
        case unmeasured

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let verdict = Self(rawValue: value) else {
                throw .typeMismatch(expected: "coherence verdict", got: value)
            }
            return verdict
        }
    }
}

extension Workspace.Coherence.Verdict {
    /// The exit status a `institute coherence` invocation reports — the
    /// same 0/1/2 shape ``Workspace/Doctor/Report/status`` uses, so a
    /// caller need not learn two conventions.
    public var status: Swift.Int32 {
        switch self {
        case .coherent: 0
        case .incoherent: 1
        case .unmeasured: 2
        }
    }
}
