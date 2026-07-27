import Foundation
import Git_Foundation

@testable import Workspace_Application

extension Workspace.Sync.Fixture {
    struct State: Equatable {
        let head: Git.Object.ID
        let origin: Git.Object.ID
        let fetch: Data?
        let status: [Git.Status.Entry]
        let workspace: Data?
        let ledger: Data?
        let canonical: [Swift.String]
        let legacy: [Swift.String]
    }
}
