@testable import Workspace_Application

extension Workspace.Inventory.Test {
    enum Failure: Swift.Error, Equatable, Sendable {
        case malformed
        case status
    }
}
