extension Workspace {
    public enum Command: Equatable, Sendable {
        case sync(dry: Bool)
        case doctor

        public static func parse(_ arguments: [String]) throws(Workspace.Error) -> Self {
            switch arguments {
            case ["sync"]:
                .sync(dry: false)
            case ["sync", "--dry-run"]:
                .sync(dry: true)
            case ["doctor"]:
                .doctor
            default:
                throw .arguments("usage: swift run workspace <sync [--dry-run] | doctor>")
            }
        }
    }
}
