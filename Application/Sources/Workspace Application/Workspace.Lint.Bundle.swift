public import File_System

extension Workspace.Lint {
    /// The rule set a package is linted with when it carries no
    /// `Lint.swift`.
    ///
    /// ## Why a default exists at all
    ///
    /// The engine ships rule-pack-agnostic: with no reachable
    /// configuration it loads zero rules and exits clean having measured
    /// nothing. Workspace previously refused such a package outright —
    /// `Lint.swift` decided whether a package was linted, and a
    /// checked-in allowlist recorded the packages excused from carrying
    /// one. That made the absence of a configuration the one way to be
    /// invisible to the linter.
    ///
    /// A default removes the exemption. It is not, however, a second
    /// standard: every case here is a bundle the prebuilt standard
    /// runner already bakes, chosen because it is **byte-for-byte the
    /// bundle the package's configured peers in the same layer
    /// activate**. So a package that adopts a `Lint.swift` tomorrow,
    /// written to the convention its layer already follows, is measured
    /// against exactly what it was measured against today. The default
    /// cannot be argued with as "the wrong rules", and it cannot be
    /// escaped by staying unconfigured.
    ///
    /// The three bundles are one lattice anchored on `institute`:
    /// `universal ⊂ institute ⊂ primitives`, and `standards` is
    /// `institute` minus two naming rules. Picking the layer's own
    /// bundle rather than one global choice is what keeps a
    /// primitives-layer package from being measured against a *weaker*
    /// set than its peers — which would reward staying unconfigured, the
    /// opposite of the point.
    ///
    /// ## This has no CI counterpart
    ///
    /// Everywhere else the lint capability runs exactly what CI runs.
    /// Here it cannot: CI's activation signal *is* the presence of
    /// `Lint.swift`, so for these packages CI runs nothing at all. A
    /// default-bundle run is Workspace's own measurement, and it is
    /// reported as one. Nothing in this type changes what the gating CI
    /// legs require.
    public enum Bundle: Equatable, Sendable {
        /// `Lint.Rule.Bundle.primitives` — the institute bundle plus the
        /// primitives-tier packs.
        case primitives

        /// `Lint.Rule.Bundle.standards` — the institute bundle minus the
        /// two naming rules the standards layer does not hold.
        case standards

        /// `Lint.Rule.Bundle.institute` — the organization-wide bundle,
        /// which transitively carries the universal tier.
        case institute
    }
}

extension Workspace.Lint.Bundle {
    /// The token the engine's baked-bundle channel carries.
    ///
    /// Spelled out rather than derived from a raw value: this string is
    /// a wire vocabulary shared with a separately-versioned binary, and
    /// it must not change silently because a case was renamed.
    public var token: Swift.String {
        switch self {
        case .primitives: "primitives"
        case .standards: "standards"
        case .institute: "institute"
        }
    }

    /// The environment variable the prebuilt standard runner reads to
    /// select which baked bundle a spawn lints with.
    ///
    /// A channel rather than a flag because the runner forwards its
    /// whole argument vector as lint targets — a flag would be
    /// indistinguishable from a path.
    static let variable = "SWIFT_LINTER_BUNDLE"
}

extension Workspace.Lint.Bundle {
    /// The bundle a package in `layer` is linted with.
    ///
    /// The mapping is read off what the layer's configured packages
    /// already do, not invented here. Measured 2026-07-29 across the 353
    /// materialized packages carrying a `Lint.swift`: every one of the
    /// 199 in `primitives` activates `Lint.Rule.Bundle.primitives`, all
    /// 28 in `standards` activate `standards`, and 123 of the 124 in
    /// `foundations` activate `institute` — the single exception being
    /// the universal rule pack's self-lint, which activates its own
    /// unbaked bundle.
    ///
    /// `components` and `applications` carry no materialized packages
    /// yet. They take `institute`, the organization-wide bundle, which
    /// is what a package above the standards layer would be given.
    public init(_ layer: Workspace.Layer) {
        switch layer {
        case .primitives: self = .primitives
        case .standards: self = .standards
        case .foundations, .components, .applications: self = .institute
        }
    }
}

extension Workspace.Lint.Bundle {
    /// The bundle for the package rooted at `package`, derived from
    /// where it sits under `hierarchy`.
    ///
    /// The sweep does not need this — it holds the inventory entry and
    /// therefore the authoritative layer. The single-package path does:
    /// `institute package lint` reads no inventory by design, and
    /// requiring one would be the ceremony that mode exists to avoid.
    ///
    /// The derivation is not a tree walk and carries no layout guess.
    /// ``Workspace/Layout/components(for:)`` puts
    /// ``Workspace/Layer/organization`` first in every materialized
    /// path, so the first component below the hierarchy **is** the
    /// layer root — this reads that invariant backwards, and agrees with
    /// the sweep's authoritative layer by construction.
    ///
    /// - Returns: `nil` when `package` is not under `hierarchy`, or when
    ///   its first component names no layer root. Reported as
    ///   ``Workspace/Lint/Measurement/Verdict/unmeasured(reason:)`` by
    ///   the caller rather than defaulted: guessing a rule set for a
    ///   package outside the layout is how a number nobody can interpret
    ///   gets published.
    public static func resolve(
        _ package: File.Directory,
        under hierarchy: File.Directory
    ) -> Self? {
        let base = Array(hierarchy.path.components)
        let full = Array(package.path.components)
        guard
            full.count > base.count,
            full.prefix(base.count).elementsEqual(base),
            let root = full.dropFirst(base.count).first
        else {
            return nil
        }
        guard
            let layer = Workspace.Layer.allCases.first(where: {
                $0.organization == root.string
            })
        else {
            return nil
        }
        return Self(layer)
    }
}
