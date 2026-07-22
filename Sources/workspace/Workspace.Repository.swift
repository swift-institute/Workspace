extension Workspace {
    public struct Repository: Codable, Equatable, Sendable {
        public let name: String
        public let url: String
        public let layer: Layer

        public init(name: String, url: String, layer: Layer) {
            self.name = name
            self.url = url
            self.layer = layer
        }
    }
}
