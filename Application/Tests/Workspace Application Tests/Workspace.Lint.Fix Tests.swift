import File_System
import Testing

@testable import Workspace_Application

extension Workspace.Lint.Fix {
    @Suite struct Test {}
}

extension Workspace.Lint.Fix.Test {
    @Test
    func `a shadow excludes only its unsafe canonical fixer`() {
        let arguments = Workspace.Lint.Fix.exclusionArguments([
            Workspace.Lint.Fix.shadowedStandardLibraryQualification
        ])

        #expect(arguments == ["--fix-excluding", "PLAT-ARCH-022"])
        #expect(!arguments.contains("IMPL-033"))
    }

    @Test
    func `exclusion arguments preserve repeated and unknown engine identifiers`() {
        let arguments = Workspace.Lint.Fix.exclusionArguments([
            "PLAT-ARCH-022", "SAFE-001", "PLAT-ARCH-022", "UNKNOWN-999",
        ])

        #expect(arguments == [
            "--fix-excluding", "PLAT-ARCH-022",
            "--fix-excluding", "SAFE-001",
            "--fix-excluding", "PLAT-ARCH-022",
            "--fix-excluding", "UNKNOWN-999",
        ])
    }

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
