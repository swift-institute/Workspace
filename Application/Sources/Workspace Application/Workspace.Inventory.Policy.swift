public import GitHub
import Tagged_Primitives

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
                        .init(name: .init("swift-components"), layer: .components),
                        .init(name: .init("swift-applications"), layer: .applications),
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
