extension Workspace.Doctor {
    /// One toolchain interrogation: the tool's reported version output
    /// against the marker the configuration requires it to contain.
    public struct Tool: Equatable, Sendable {
        public let name: Swift.String
        public let required: Swift.String
        public let output: Swift.String

        public init(name: Swift.String, required: Swift.String, output: Swift.String) {
            self.name = name
            self.required = required
            self.output = output
        }
    }
}

extension Workspace.Doctor {
    /// The configured Swift and Xcode versions are the ones installed.
    public static let toolchain = Check<Tool>(
        name: "toolchain",
        scope: .contributor,
        controls: .init(
            positive: .init(name: "control", required: "required-marker", output: "another version"),
            negative: .init(name: "control", required: "required-marker", output: "the required-marker version")
        )
    ) { tool in
        guard !tool.output.contains(tool.required) else { return [] }
        let found = tool.output.split(separator: "\n").first ?? "no output"
        return [
            .init(
                severity: .error,
                message: "\(tool.name): \(tool.required) is required; found \(found)"
            )
        ]
    }

    func toolchain() -> Outcome {
        do throws(Workspace.Error) {
            return Self.toolchain.run(
                population: [
                    .init(
                        name: "swift",
                        required: configuration.swift,
                        output: try tool("swift", ["--version"])
                    ),
                    .init(
                        name: "xcodebuild",
                        required: "Xcode \(configuration.xcode)",
                        output: try tool("xcodebuild", ["-version"])
                    ),
                ],
                inventory: 2
            )
        } catch {
            return Self.toolchain.unmeasured(
                reason: "cannot interrogate the toolchain: \(error)"
            )
        }
    }
}
