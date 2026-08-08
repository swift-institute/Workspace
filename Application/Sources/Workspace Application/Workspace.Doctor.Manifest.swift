internal import Async_Fanout
import File_System
private import Package_Manager

extension Workspace.Doctor {
    /// One selected, materialized repository's evaluated manifest identity
    /// against its inventory name.
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
    /// Every selected, materialized repository's manifest identity is its
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

    /// One `swift package dump-package` per materialized repository,
    /// gathered concurrently.
    ///
    /// SwiftPM takes its exclusive lock on the *target package's* `.build`,
    /// so evaluations of distinct packages do not contend; the population is
    /// rebuilt in selection order regardless of completion order.
    func manifest(_ materialized: [(Workspace.Repository, File.Directory)]) async -> Outcome {
        Self.manifest.run(
            population: await fanout.map(
                materialized,
                completed: progress.steps(
                    "manifest-identity: evaluated",
                    of: materialized.count
                )
            ) { entry in
                let (repository, path) = entry
                return Manifest(name: repository.name, identity: self.identity(at: path))
            },
            inventory: selection.repositories.count
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
