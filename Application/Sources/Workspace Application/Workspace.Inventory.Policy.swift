public import GitHub

extension Workspace.Inventory {
    public struct Policy: Equatable, Sendable {
        public let organizations: [Organization]
        public let denied: Set<Workspace.Repository.Key>
        public let limit: GitHub.Organization.Repositories.Traversal.Limit

        public init(
            organizations: [Organization],
            denied: Set<Workspace.Repository.Key>,
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

            self.organizations = organizations
            self.denied = denied
            self.limit = limit
        }

        public static func institute() -> Self {
            guard
                let pages = GitHub.Organization.Repositories.Traversal.Limit.Pages(rawValue: 100),
                let items = GitHub.Organization.Repositories.Traversal.Limit.Items(rawValue: 10_000)
            else { preconditionFailure("The Institute inventory bounds are invalid") }

            do throws(Error) {
                return try Self(
                    organizations: [
                        .init(name: .init(rawValue: "swift-primitives"), layer: .primitives),
                        .init(name: .init(rawValue: "swift-standards"), layer: .standards),
                        .init(name: .init(rawValue: "swift-ietf"), layer: .standards),
                        .init(name: .init(rawValue: "swift-iso"), layer: .standards),
                        .init(name: .init(rawValue: "swift-w3c"), layer: .standards),
                        .init(name: .init(rawValue: "swift-whatwg"), layer: .standards),
                        .init(name: .init(rawValue: "swift-ieee"), layer: .standards),
                        .init(name: .init(rawValue: "swift-iec"), layer: .standards),
                        .init(name: .init(rawValue: "swift-ecma"), layer: .standards),
                        .init(name: .init(rawValue: "swift-incits"), layer: .standards),
                        .init(name: .init(rawValue: "swift-nist"), layer: .standards),
                        .init(name: .init(rawValue: "swift-linux-foundation"), layer: .standards),
                        .init(name: .init(rawValue: "swift-microsoft"), layer: .standards),
                        .init(name: .init(rawValue: "swift-arm-ltd"), layer: .standards),
                        .init(name: .init(rawValue: "swift-intel"), layer: .standards),
                        .init(name: .init(rawValue: "swift-riscv"), layer: .standards),
                        .init(name: .init(rawValue: "swift-foundations"), layer: .foundations),
                        .init(name: .init(rawValue: "swift-components"), layer: .components),
                        .init(name: .init(rawValue: "swift-applications"), layer: .applications),
                    ],
                    denied: [],
                    limit: .init(pages: pages, items: items)
                )
            } catch {
                preconditionFailure("The Institute inventory policy is invalid: \(error)")
            }
        }
    }
}
