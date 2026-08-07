private import File_System

extension Workspace.Doctor {
    /// One assertion about the installed linter.
    public enum Linter: Equatable, Sendable {
        /// swift-linter must be installed before either lint mode can
        /// run at all.
        case installed(digest: Swift.String?)

        /// The installed build must be the one CI consumes.
        case parity(findings: [Swift.String])
    }
}

extension Workspace.Doctor {
    /// The local linter is installed, and it is the build CI gates on.
    ///
    /// The check is not "does a linter exist". It is "would linting
    /// here produce the answer CI produces" — which is the only
    /// property worth reporting, because a local capability that can
    /// disagree with CI teaches people to trust whichever signal is
    /// convenient.
    public static let linter = Check<Linter>(
        name: "linter",
        scope: .contributor,
        controls: .init(
            positive: .installed(digest: nil),
            negative: .installed(digest: "e837b75b3cb9780c")
        )
    ) { subject in
        switch subject {
        case .installed(let digest):
            guard digest == nil else { return [] }
            // A warning, not an error. An absent local linter is a
            // missing capability, not a defective checkout — CI still
            // gates, and a bare clone that has never run `lint install`
            // is in a legitimate state. Divergence below is an error,
            // because that one produces answers that disagree with the
            // gate while looking authoritative.
            return [
                .init(
                    severity: .warning,
                    message: "swift-linter is not installed; run `institute lint install`. "
                        + "Neither `institute lint` nor `institute package lint` can run without it."
                )
            ]
        case .parity(let findings):
            return findings.map { .init(severity: .error, message: $0) }
        }
    }

    func linter() -> Outcome {
        let lint = Workspace.Lint(root: root)
        let digest: Swift.String?
        do throws(Workspace.Error) {
            digest = lint.manifestFile.stat.isFile ? try lint.installedManifest().digest : nil
        } catch {
            return Self.linter.unmeasured(
                reason: "cannot read the installed linter manifest: \(error)"
            )
        }
        guard digest != nil else {
            return Self.linter.run(population: [.installed(digest: nil)], inventory: 2)
        }

        let findings: [Swift.String]
        do throws(Workspace.Error) {
            findings = try lint.divergence()
        } catch {
            // Reaching the published manifest needs the network. Failing
            // to reach it is not evidence of parity and is not evidence
            // against it, so it is reported as unmeasured rather than
            // quietly passing — a check that goes green when it could not
            // look is the failure this whole capability is built around.
            return Self.linter.unmeasured(
                reason: "cannot compare against the linter build CI consumes: \(error)"
            )
        }
        return Self.linter.run(
            population: [.installed(digest: digest), .parity(findings: findings)],
            inventory: 2
        )
    }
}
