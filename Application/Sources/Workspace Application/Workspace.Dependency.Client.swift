internal import Byte_Primitives

extension Workspace.Dependency {
    /// The three remote reads the audit composes.
    ///
    /// Tests supply controlled repositories and failures. The command supplies
    /// the GitHub-backed client, keeping transport and measurement independent.
    struct Client: Sendable {
        let repository:
            @Sendable (Workspace.Repository.Key) async -> Fetch<Metadata>
        let source:
            @Sendable (Metadata) async -> Fetch<Source>
        let content:
            @Sendable (Workspace.Repository.Key, Source.Blob) async -> Fetch<[Byte]>

        init(
            repository:
                @escaping @Sendable (Workspace.Repository.Key) async -> Fetch<Metadata>,
            source:
                @escaping @Sendable (Metadata) async -> Fetch<Source>,
            content:
                @escaping @Sendable (
                    Workspace.Repository.Key,
                    Source.Blob
                ) async -> Fetch<[Byte]>
        ) {
            self.repository = repository
            self.source = source
            self.content = content
        }
    }
}
