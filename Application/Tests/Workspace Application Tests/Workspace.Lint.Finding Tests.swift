import Testing

@testable import Workspace_Application

extension Workspace.Lint.Finding {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}

        fileprivate static let sarif = #"""
            {
              "version": "2.1.0",
              "runs": [{
                "results": [
                  {
                    "ruleId": "PLAT-ARCH-022",
                    "level": "warning",
                    "message": {"text": "Advisory"},
                    "locations": [{"physicalLocation": {
                      "artifactLocation": {"uri": "Tests/Bytes Tests.swift"},
                      "region": {"startLine": 7, "startColumn": 3}
                    }}]
                  },
                  {
                    "ruleId": "IMPL-001",
                    "level": "error",
                    "message": {"text": "Error"},
                    "locations": [{"physicalLocation": {
                      "artifactLocation": {"uri": "/tmp/swift-bytes/Sources/Bytes.swift"},
                      "region": {"startLine": 2, "startColumn": 1}
                    }}]
                  }
                ]
              }]
            }
            """#
    }
}

extension Workspace.Lint.Finding.Test.Unit {
    @Test
    func `SARIF supplies exact severity rule and package-relative sites`() throws {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/swift-bytes",
            status: 1,
            standardOutput: Workspace.Lint.Finding.Test.sarif,
            standardError: "swift-bytes · 2 active rules · 2 files linted · 2 violations",
            format: .sarif
        )

        #expect(measurement.verdict == .violations(count: 2, failing: true))
        let findings = try #require(measurement.structured)
        #expect(findings.count == 2)
        #expect(findings[0].rule == "IMPL-001")
        #expect(findings[0].severity == .error)
        #expect(findings[0].path == "Sources/Bytes.swift")
        #expect(findings[1].rule == "PLAT-ARCH-022")
        #expect(findings[1].severity == .warning)
        #expect(findings[1].path == "Tests/Bytes Tests.swift")
    }
}

extension Workspace.Lint.Finding.Test.`Edge Case` {
    @Test
    func `structured count disagreement is unmeasured`() {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/swift-bytes",
            status: 0,
            standardOutput: Workspace.Lint.Finding.Test.sarif,
            standardError: "swift-bytes · 2 active rules · 2 files linted · 3 violations",
            format: .sarif
        )

        #expect(measurement.verdict.isUnmeasured)
        #expect(measurement.structured == nil)
    }

    @Test
    func `human output cannot masquerade as structured evidence`() {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/swift-bytes",
            status: 0,
            standardOutput: "/tmp/swift-bytes/Sources/Bytes.swift:1:1: warning: finding",
            standardError: "swift-bytes · 2 active rules · 1 file linted · 1 violation",
            format: .sarif
        )

        #expect(measurement.verdict.isUnmeasured)
        #expect(measurement.structured == nil)
        #expect(measurement.prerequisite == .sarif)
    }

    @Test
    func `strict exit and structured severity disagreement is unmeasured`() {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/swift-bytes",
            status: 0,
            standardOutput: Workspace.Lint.Finding.Test.sarif,
            standardError: "swift-bytes · 2 active rules · 2 files linted · 2 violations",
            format: .sarif
        )

        #expect(measurement.verdict.isUnmeasured)
        #expect(measurement.structured == nil)
    }
}
