extension Build {
    /// A SwiftPM operation supported by the build coordinator.
    public enum Action: Swift.String, CaseIterable, Sendable {
        case build
        case test
        case run
        case resolve
        case update
        case clean
        case dumpPackage = "dump-package"
    }
}

extension Build.Action {
    var command: [Swift.String] {
        switch self {
        case .build, .test, .run:
            ["swift", rawValue]
        case .resolve, .update, .clean, .dumpPackage:
            ["swift", "package", rawValue]
        }
    }

    var acceptsFreshScratch: Swift.Bool {
        switch self {
        case .build, .test: true
        case .run, .resolve, .update, .clean, .dumpPackage: false
        }
    }

    var acceptsJobs: Swift.Bool {
        switch self {
        case .build, .test, .run: true
        case .resolve, .update, .clean, .dumpPackage: false
        }
    }

    func invocation(
        jobs: Swift.Int,
        scratchPath: Swift.String?,
        arguments: [Swift.String]
    ) throws(Build.Error) -> [Swift.String] {
        guard jobs > 0 else {
            throw .configuration("jobs must be greater than zero")
        }
        for argument in arguments where Self.isCoordinatorOwned(argument) {
            throw .configuration(
                "SwiftPM argument \(argument) is owned by the build coordinator"
            )
        }

        var invocation = command
        if acceptsJobs {
            invocation += ["-j", "\(jobs)"]
        }
        if let scratchPath {
            invocation += ["--scratch-path", scratchPath]
        }
        invocation += arguments
        return invocation
    }

    private static func isCoordinatorOwned(
        _ argument: Swift.String
    ) -> Swift.Bool {
        if argument == "-j" || argument.hasPrefix("-j") {
            return true
        }
        return [
            "--package-path",
            "--scratch-path",
            "--build-path",
            "--cache-path",
            "--config-path",
            "--security-path",
            "--jobs",
        ].contains { option in
            argument == option || argument.hasPrefix("\(option)=")
        }
    }
}
