import Testing

@testable import Build_Coordinator

@Suite
struct `Build Action Tests` {
    @Test
    func `build and test are direct Swift operations with isolated scratch support`() {
        #expect(Build.Action.build.command == ["swift", "build"])
        #expect(Build.Action.test.command == ["swift", "test"])
        #expect(Build.Action.build.acceptsFreshScratch)
        #expect(Build.Action.test.acceptsFreshScratch)
    }

    @Test
    func `package administration operations use the Swift package namespace`() {
        #expect(Build.Action.resolve.command == ["swift", "package", "resolve"])
        #expect(Build.Action.dumpPackage.command == ["swift", "package", "dump-package"])
        #expect(!Build.Action.resolve.acceptsFreshScratch)
    }

    @Test
    func `invocation owns concurrency and fresh build state`() throws {
        let invocation = try Build.Action.test.invocation(
            jobs: 3,
            scratchPath: "/tmp/workspace-scratch",
            arguments: ["--filter", "Unit"]
        )

        #expect(
            invocation == [
                "swift", "test",
                "-j", "3",
                "--scratch-path", "/tmp/workspace-scratch",
                "--filter", "Unit",
            ]
        )
    }

    @Test(arguments: [
        "--package-path",
        "--package-path=/tmp/other",
        "--scratch-path",
        "--build-path=/tmp/other",
        "--cache-path",
        "--config-path=/tmp/other",
        "--security-path",
        "-j",
        "-j8",
        "--jobs=8",
    ])
    func `forwarded arguments cannot override coordinator state`(
        argument: Swift.String
    ) {
        #expect(
            throws: Build.Error.configuration(
                "SwiftPM argument \(argument) is owned by the build coordinator"
            )
        ) {
            _ = try Build.Action.test.invocation(
                jobs: 3,
                scratchPath: nil,
                arguments: [argument]
            )
        }
    }
}
