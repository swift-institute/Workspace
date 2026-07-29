public import GitHub
// `vacant` is a Set of GitHub.Organization.Name, a Tagged alias, so the
// declaration is only well-formed with the module imported publicly.
public import Tagged_Primitives

extension Workspace.Inventory {
    public struct Policy: Equatable, Sendable {
        public let organizations: [Organization]
        public let denied: Set<Workspace.Repository.Key>
        /// Organizations known to list no public repositories.
        ///
        /// Discovery fails when an organization lists nothing, because a
        /// silently short roster is worse than no roster. An organization that
        /// is *genuinely* empty must therefore say so here, and saying so is
        /// deliberately awkward: the entry is a dated claim about the fleet
        /// that stops being true the moment the organization publishes
        /// anything, and it should be removed then.
        ///
        /// Empty by default, which is the strict reading — no organization may
        /// list nothing.
        public let vacant: Set<GitHub.Organization.Name>
        public let limit: GitHub.Organization.Repositories.Traversal.Limit

        public init(
            organizations: [Organization],
            denied: Set<Workspace.Repository.Key>,
            vacant: Set<GitHub.Organization.Name> = [],
            limit: GitHub.Organization.Repositories.Traversal.Limit
        ) throws(Error) {
            var names = Set<GitHub.Organization.Name>()
            for organization in organizations {
                guard names.insert(organization.name).inserted else {
                    throw .organization(organization.name)
                }
            }
            for key in denied where !names.contains(key.owner) {
                throw .deny(key)
            }
            for name in vacant where !names.contains(name) {
                throw .vacancy(name)
            }

            self.organizations = organizations
            self.denied = denied
            self.vacant = vacant
            self.limit = limit
        }
    }
}

extension Workspace.Inventory.Policy {
    /// The organizations discovery covers.
    ///
    /// **Three layers only.** `swift-components` and `swift-applications` were
    /// listed here until 2026-07-28, encoding a superseded L4/L5 doctrine. The
    /// principal ruled that day that there is no layer above L3, and both orgs
    /// were emptied — so discovering into them would have re-materialized the
    /// very roots the ruling removed, the moment this ran. They are absent
    /// deliberately; do not restore them without a new ruling.
    public static func institute() -> Self {
        guard
            let pages = GitHub.Organization.Repositories.Traversal.Limit.Pages(rawValue: 100),
            let items = GitHub.Organization.Repositories.Traversal.Limit.Items(rawValue: 10_000)
        else { preconditionFailure("The Institute inventory bounds are invalid") }

        do throws(Error) {
            return try Self(
                organizations: [
                    .init(name: .init("swift-primitives"), layer: .primitives),
                    .init(name: .init("swift-standards"), layer: .standards),
                    .init(name: .init("swift-ietf"), layer: .standards),
                    .init(name: .init("swift-iso"), layer: .standards),
                    .init(name: .init("swift-w3c"), layer: .standards),
                    .init(name: .init("swift-whatwg"), layer: .standards),
                    .init(name: .init("swift-ieee"), layer: .standards),
                    .init(name: .init("swift-iec"), layer: .standards),
                    .init(name: .init("swift-ecma"), layer: .standards),
                    .init(name: .init("swift-incits"), layer: .standards),
                    .init(name: .init("swift-nist"), layer: .standards),
                    .init(name: .init("swift-linux-foundation"), layer: .standards),
                    .init(name: .init("swift-microsoft"), layer: .standards),
                    .init(name: .init("swift-arm-ltd"), layer: .standards),
                    .init(name: .init("swift-intel"), layer: .standards),
                    .init(name: .init("swift-riscv"), layer: .standards),
                    .init(name: .init("swift-foundations"), layer: .foundations),
                ],
                // Two packages hold an upstream SwiftPM identity that a
                // third party inside our graph also needs, and workspace
                // membership alone is enough to capture it — measured
                // 2026-07-29, with no Institute manifest declaring either by
                // URL, the workspace still failed on
                // `product 'RealModule' required by package 'swift-algorithms'
                // target 'Algorithms' not found in package 'swift-numerics'`.
                // Migrating our own consumers cannot reach that, because the
                // capturing edge is the roster entry rather than a manifest.
                //
                // Denying them is the interim, not the remedy. The remedy is
                // absorption into our own idiom, which is unblocked once the
                // third parties that need upstream's spelling leave the graph.
                //
                // **Exit condition, deliberately narrow:** remove an entry when
                // the Vapor closure (`vapor`, `async-kit`, `async-http-client`,
                // `swift-nio-extras` — and for `swift-metrics` additionally
                // `postgres-nio` and `swift-configuration`) is gone from the
                // dependency closure. Not when the package looks ready, not
                // when someone wants it back in Xcode. Re-entry before then
                // silently re-captures the identity for all 445 packages, which
                // is the same latent condition already carried by `swift-log`
                // and `swift-date-parsing` — with the difference that these two
                // are known to fire rather than merely able to.
                //
                // See swift-institute/Workspace#7.
                denied: [
                    .init(owner: .init("swift-foundations"), name: .init("swift-numerics")),
                    .init(owner: .init("swift-foundations"), name: .init("swift-metrics")),
                ],
                // Measured 2026-07-28 against `orgs/<name>/repos?type=public`,
                // the same query discovery issues: every policy organization
                // lists at least one public repository except `swift-nist`,
                // which holds a single non-public repository and therefore
                // lists none. Remove this the moment it publishes anything.
                //
                // Counted with the wrong filter first. `gh repo list` reports
                // repositories at every visibility, which said `swift-nist`
                // held 1 and made an empty public listing look impossible. The
                // population a control measures has to be the one the code
                // queries.
                vacant: [.init("swift-nist")],
                limit: .init(pages: pages, items: items)
            )
        } catch {
            preconditionFailure("The Institute inventory policy is invalid: \(error)")
        }
    }
}
