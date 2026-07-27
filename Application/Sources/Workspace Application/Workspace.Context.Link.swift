internal import File_System

extension Workspace.Context {
    struct Link: Sendable {
        let path: File.Path
        let target: File.Path

        init(path: File.Path, target: File.Path) {
            self.path = path
            self.target = target
        }
    }
}
