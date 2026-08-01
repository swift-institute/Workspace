import File_System
import Testing

@testable import Workspace_Application

extension Workspace.Lint.Fix {
    @Suite struct Test {}
}

extension Workspace.Lint.Fix.Test {
    @Test
    func `declared roots use the linter fix channel without losing order or spaces`() {
        let roots = [
            File.Directory("/fixture/package/Sources/Library"),
            File.Directory("/fixture/package/Tests/Library Tests"),
        ]

        #expect(Workspace.Lint.Fix.targetsVariable == "SWIFT_LINTER_FIX_TARGETS")
        #expect(
            Workspace.Lint.Fix.targets(roots)
                == "[\"/fixture/package/Sources/Library\",\"/fixture/package/Tests/Library Tests\"]"
        )
    }
}
