public import GitHub
public import Tagged_Primitives

extension Workspace.Inventory.Policy {
    public enum Error: Swift.Error, Equatable, Sendable {
        case organization(GitHub.Organization.Name)
        case deny(Workspace.Repository.Key)
        /// An organization permitted to list nothing is not in the policy.
        ///
        /// The permission is only meaningful for an organization discovery
        /// actually visits, and one naming an absent organization is almost
        /// always a rename that silenced the guard for a name nothing queries.
        case vacancy(GitHub.Organization.Name)
    }
}
