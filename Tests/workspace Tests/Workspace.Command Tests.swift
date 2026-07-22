import Testing

@testable import workspace

@Test
func parsesSync() {
    do {
        let command = try Workspace.Command.parse(["sync"])
        #expect(command == .sync(dry: false))
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}

@Test
func parsesDrySync() {
    do {
        let command = try Workspace.Command.parse(["sync", "--dry-run"])
        #expect(command == .sync(dry: true))
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}

@Test
func parsesDoctor() {
    do {
        let command = try Workspace.Command.parse(["doctor"])
        #expect(command == .doctor)
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}
