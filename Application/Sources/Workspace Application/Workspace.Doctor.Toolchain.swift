extension Workspace.Doctor {
    /// One toolchain assertion: a tool's version output against the
    /// marker the configuration requires, an override variable that
    /// must be unset, or a resolved tool's residence inside the
    /// selected developer directory.
    ///
    /// The workspace supports exactly one toolchain configuration —
    /// Xcode's bundled toolchain, with no `TOOLCHAINS` override — so
    /// each case asserts one face of that single configuration.
    public enum Toolchain: Equatable, Sendable {
        /// The tool's reported version must contain the required marker.
        case version(tool: Swift.String, required: Swift.String, output: Swift.String)
        /// The override variable must be unset; `value` is what the
        /// invoking environment carries, `nil` when unset.
        case override(variable: Swift.String, value: Swift.String?)
        /// The resolved tool must live inside the selected developer
        /// directory — the toolchain bundled with the selected Xcode.
        case residence(tool: Swift.String, resolved: Swift.String, developer: Swift.String)
    }
}

extension Workspace.Doctor {
    /// The toolchain is the single supported configuration: the
    /// configured Swift and Xcode versions are the ones installed, no
    /// `TOOLCHAINS` override is set, and the resolved `swift` is the
    /// one bundled with the selected Xcode.
    public static let toolchain = Check<Toolchain>(
        name: "toolchain",
        scope: .contributor,
        controls: .init(
            positive: .override(variable: "control", value: "an-override"),
            negative: .override(variable: "control", value: nil)
        )
    ) { subject in
        switch subject {
        case .version(let tool, let required, let output):
            guard !output.contains(required) else { return [] }
            let found = output.split(separator: "\n").first ?? "no output"
            return [
                .init(
                    severity: .error,
                    message: "\(tool): \(required) is required; found \(found)"
                )
            ]
        case .override(let variable, let value):
            guard let value else { return [] }
            return [
                .init(
                    severity: .error,
                    message: "\(variable) is set to \(value); the workspace supports exactly "
                        + "one toolchain configuration — Xcode's bundled toolchain. Unset \(variable)."
                )
            ]
        case .residence(let tool, let resolved, let developer):
            guard !resolved.hasPrefix(developer) else { return [] }
            return [
                .init(
                    severity: .error,
                    message: "\(tool) resolves to \(resolved), outside the selected Xcode "
                        + "at \(developer)"
                )
            ]
        }
    }

    func toolchain() -> Outcome {
        do throws(Workspace.Error) {
            let developer = Self.line(try tool("xcode-select", ["--print-path"]))
            guard !developer.isEmpty else {
                return Self.toolchain.unmeasured(
                    reason: "xcode-select reported no developer directory"
                )
            }
            let resolved = Self.line(try tool("xcrun", ["--find", "swift"]))
            guard !resolved.isEmpty else {
                return Self.toolchain.unmeasured(reason: "xcrun resolved no swift")
            }
            return Self.toolchain.run(
                population: [
                    .version(
                        tool: "swift",
                        required: configuration.swift,
                        output: try tool("swift", ["--version"])
                    ),
                    .version(
                        tool: "xcodebuild",
                        required: "Xcode \(configuration.xcode)",
                        output: try tool("xcodebuild", ["-version"])
                    ),
                    .override(variable: "TOOLCHAINS", value: environment("TOOLCHAINS")),
                    .residence(tool: "swift", resolved: resolved, developer: developer),
                ],
                inventory: 4
            )
        } catch {
            return Self.toolchain.unmeasured(
                reason: "cannot interrogate the toolchain: \(error)"
            )
        }
    }

    /// The first line of a tool's output, without the trailing newline —
    /// the shape `xcode-select --print-path` and `xcrun --find` report.
    static func line(_ output: Swift.String) -> Swift.String {
        output.split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(Swift.String.init) ?? ""
    }
}
