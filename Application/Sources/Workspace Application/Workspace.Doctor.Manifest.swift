import File_System
private import Package_Manager

extension Workspace.Doctor {
    /// One materialized repository's evaluated manifest identity against
    /// its inventory name.
    public struct Manifest: Equatable, Sendable {
        public let name: Swift.String
        public let identity: Identity

        public init(name: Swift.String, identity: Identity) {
            self.name = name
            self.identity = identity
        }
    }
}

extension Workspace.Doctor {
    /// Every materialized repository's manifest identity is its
    /// inventory name.
    public static let manifest = Check<Manifest>(
        name: "manifest-identity",
        scope: .contributor,
        controls: .init(
            positive: .init(name: "control", identity: .evaluated("other")),
            negative: .init(name: "control", identity: .evaluated("control"))
        )
    ) { manifest in
        switch manifest.identity {
        case .evaluated(let identity):
            identity == manifest.name
                ? []
                : [
                    .init(
                        severity: .error,
                        message: "\(manifest.name): manifest identity is \(identity)"
                    )
                ]
        case .unevaluable(let diagnostic):
            [
                .init(
                    severity: .error,
                    message: "\(manifest.name): cannot evaluate manifest: \(diagnostic)"
                )
            ]
        }
    }

    func manifest(_ materialized: [(Workspace.Repository, File.Directory)]) -> Outcome {
        Self.manifest.run(
            population: materialized.map { repository, path in
                .init(name: repository.name, identity: identity(at: path))
            },
            inventory: configuration.repositories.count
        )
    }

    private func identity(at repository: File.Directory) -> Manifest.Identity {
        do throws(Package.Manager.Error) {
            return .evaluated(try packages.manifest(at: repository.description).name.underlying)
        } catch {
            return .unevaluable("\(error)")
        }
    }
}
