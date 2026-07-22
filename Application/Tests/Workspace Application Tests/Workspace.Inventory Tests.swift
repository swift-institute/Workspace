import Testing

@testable import Workspace_Application

extension Workspace.Inventory {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}
