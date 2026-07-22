extension Workspace.Shell {
    public struct Result: Sendable {
        public let code: Int32
        public let text: String

        public init(code: Int32, text: String) {
            self.code = code
            self.text = text
        }
    }
}
