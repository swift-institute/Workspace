internal import File_System

extension Workspace.Context {
    struct Document: Sendable {
        let source: File
        let target: File
        let marker: Swift.String?

        init(source: File, target: File, marker: Swift.String? = nil) {
            self.source = source
            self.target = target
            self.marker = marker
        }
    }
}
