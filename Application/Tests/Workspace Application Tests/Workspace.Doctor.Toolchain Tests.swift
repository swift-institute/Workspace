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

// MARK: - The version requirement is a floor, not a pin (#57)

extension Workspace.Doctor.Test.Unit {
    /// The defect this floor exists to prevent: under string containment a
    /// toolchain *newer* than the requirement failed, so no single number
    /// could be green on both the maintainer machine and a contributor's.
    @Test
    func `a toolchain newer than the configured minimum passes`() {
        let outcome = Workspace.Doctor.toolchain.run(
            population: [
                .version(
                    tool: "swift",
                    prefix: "Swift version ",
                    minimum: "6.3.3",
                    output: "swift-driver version: 1.168.5 Apple Swift version 6.4 "
                        + "(swiftlang-6.4.0.27.1)"
                ),
                .version(
                    tool: "xcodebuild",
                    prefix: "Xcode ",
                    minimum: "26.6",
                    output: "Xcode 27.0\nBuild version 27A5228h"
                ),
            ],
            inventory: 2
        )

        #expect(outcome.result == .ok(population: 2))
    }

    @Test
    func `a toolchain exactly at the configured minimum passes`() {
        let outcome = Workspace.Doctor.toolchain.run(
            population: [
                .version(
                    tool: "xcodebuild",
                    prefix: "Xcode ",
                    minimum: "26.6",
                    output: "Xcode 26.6\nBuild version 17F113"
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .ok(population: 1))
    }

    @Test
    func `a toolchain older than the configured minimum is an error naming both versions`() {
        let outcome = Workspace.Doctor.toolchain.run(
            population: [
                .version(
                    tool: "swift",
                    prefix: "Swift version ",
                    minimum: "6.4",
                    output: "Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)"
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .finding(severity: .error, population: 1))
        #expect(
            outcome.findings.contains {
                $0.message == "swift: 6.4 or newer is required; found 6.3.3"
            }
        )
    }

    /// Ordering is numeric per component, so a longer version is not
    /// automatically newer — `6.3.3` must stay older than `6.4`.
    @Test
    func `version ordering compares components numerically rather than lexically`() {
        typealias Version = Workspace.Doctor.Toolchain.Version

        #expect(Version("6.3.3")! < Version("6.4")!)
        #expect(Version("26.6")! < Version("27.0")!)
        #expect(Version("6.10")! > Version("6.9")!)
        #expect(Version("26.6") == Version("26.6.0"))
        #expect(Version("6.4-dev") == nil)
        #expect(Version("") == nil)
    }

    @Test
    func `output carrying no readable version is an error rather than a silent pass`() {
        let outcome = Workspace.Doctor.toolchain.run(
            population: [
                .version(
                    tool: "swift",
                    prefix: "Swift version ",
                    minimum: "6.3.3",
                    output: "error: no toolchain selected"
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .finding(severity: .error, population: 1))
        #expect(outcome.findings.contains { $0.message.contains("cannot read a version") })
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
