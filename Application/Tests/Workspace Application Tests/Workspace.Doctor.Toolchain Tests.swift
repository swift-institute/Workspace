import Testing

@testable import Workspace_Application

// MARK: - Toolchain assertion (W2)

extension Workspace.Doctor.Test.Unit {
    @Test
    func `a set TOOLCHAINS override is an error naming the variable and the value found`() {
        let outcome = Workspace.Doctor.toolchain.run(
            population: [.override(variable: "TOOLCHAINS", value: "com.example.toolchain")],
            inventory: 1
        )

        #expect(outcome.result == .finding(severity: .error, population: 1))
        #expect(
            outcome.findings.contains {
                $0.message.contains("TOOLCHAINS is set to com.example.toolchain")
            }
        )
    }

    @Test
    func `an unset override variable does not fire`() {
        let outcome = Workspace.Doctor.toolchain.run(
            population: [.override(variable: "TOOLCHAINS", value: nil)],
            inventory: 1
        )

        #expect(outcome.result == .ok(population: 1))
    }

    @Test
    func `a swift resolved outside the selected Xcode is an error`() {
        let outcome = Workspace.Doctor.toolchain.run(
            population: [
                .residence(
                    tool: "swift",
                    resolved: "/Library/Toolchains/elsewhere.xctoolchain/usr/bin/swift",
                    developer: "/Library/Developer/Xcode.app/Contents/Developer"
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .finding(severity: .error, population: 1))
        #expect(outcome.findings.contains { $0.message.contains("outside the selected Xcode") })
    }

    @Test
    func `a swift resolved inside the selected Xcode passes`() {
        let outcome = Workspace.Doctor.toolchain.run(
            population: [
                .residence(
                    tool: "swift",
                    resolved: Workspace.Doctor.Fixture.developer
                        + "/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift",
                    developer: Workspace.Doctor.Fixture.developer
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .ok(population: 1))
    }
}

extension Workspace.Doctor.Test.Integration {
    @Test
    func `a run with TOOLCHAINS set fails with a specific error naming the variable`() async throws {
        let fixture = try Workspace.Doctor.Fixture(repositories: [])
        defer { fixture.remove() }
        try Workspace.Xcode.write([], at: fixture.directory)

        let report = await fixture.doctor(environment: { variable in
            variable == "TOOLCHAINS" ? "com.example.toolchain" : nil
        }).run()

        #expect(report.status == 1)
        let toolchain = report.outcomes.first { $0.check == "toolchain" }
        #expect(toolchain?.result == .finding(severity: .error, population: 4))
        #expect(
            toolchain?.findings.contains {
                $0.message.contains("TOOLCHAINS is set to com.example.toolchain")
            } == true
        )
    }

    @Test
    func `a clean toolchain measures all four assertions`() async throws {
        let fixture = try Workspace.Doctor.Fixture(repositories: [])
        defer { fixture.remove() }
        try Workspace.Xcode.write([], at: fixture.directory)

        let report = await fixture.doctor().run()

        let toolchain = report.outcomes.first { $0.check == "toolchain" }
        #expect(toolchain?.result == .ok(population: 4))
    }

    @Test
    func `a toolchain that cannot be interrogated is unmeasured and exits 2 rather than passing`()
        async throws
    {
        let fixture = try Workspace.Doctor.Fixture(repositories: [])
        defer { fixture.remove() }
        try Workspace.Xcode.write([], at: fixture.directory)

        let report = await fixture.doctor(tool: {
            (executable, _) throws(Workspace.Error) -> Swift.String in
            throw .process("\(executable) is unavailable")
        }).run()

        #expect(report.status == 2)
        let toolchain = report.outcomes.first { $0.check == "toolchain" }
        #expect(
            toolchain?.result
                == .unmeasured(
                    reason: "cannot interrogate the toolchain: xcode-select is unavailable"
                )
        )
    }
}
