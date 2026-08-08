import Command
import Testing

@testable import Workspace_Application

@Suite
struct `Workspace CLI GitHub Tests` {

    // The minting mechanism itself lives in swift-github as the 'GitHub App'
    // product (TX-APP1A) and is tested there; what remains here is the CLI
    // surface that composes it.

    @Test
    func `accepts github token with an organization`() throws {
        var cli = Workspace.CLI(operation: .github, modes: [.token], organization: "swift-primitives")
        try cli.validate()
    }

    @Test
    func `requires an organization for github token`() {
        var cli = Workspace.CLI(operation: .github, modes: [.token])
        #expect(throws: Command.Error.self) { try cli.validate() }
    }

    @Test
    func `requires the token mode after github`() {
        var cli = Workspace.CLI(operation: .github, modes: [], organization: "swift-primitives")
        #expect(throws: Command.Error.self) { try cli.validate() }
    }

    @Test
    func `rejects credential flags outside github token`() {
        // A credential flag silently ignored mints a *wider* token than the
        // caller asked for, and nothing downstream can tell the difference.
        var narrowed = Workspace.CLI(operation: .doctor, permissions: ["contents=read"])
        #expect(throws: Command.Error.self) { try narrowed.validate() }
        var scoped = Workspace.CLI(operation: .sync, organization: "swift-primitives")
        #expect(throws: Command.Error.self) { try scoped.validate() }
    }
}
