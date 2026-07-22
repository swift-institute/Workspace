public import Foundation

extension Workspace {
    public struct Configuration: Codable, Equatable, Sendable {
        public let version: Int
        public let scope: String
        public let swift: String
        public let xcode: String
        public let repositories: [Repository]

        public init(version: Int, scope: String, swift: String, xcode: String, repositories: [Repository]) {
            self.version = version
            self.scope = scope
            self.swift = swift
            self.xcode = xcode
            self.repositories = repositories
        }

        public static func load(at root: URL) throws(Workspace.Error) -> Self {
            let path = root.appending(path: "Workspace.json")
            let data: Data
            do {
                data = try Data(contentsOf: path)
            } catch {
                throw .configuration("cannot read \(path.path): \(error)")
            }

            let configuration: Self
            do {
                configuration = try JSONDecoder().decode(Self.self, from: data)
            } catch {
                throw .configuration("cannot decode \(path.path): \(error)")
            }

            guard configuration.version == 1 else {
                throw .configuration("unsupported Workspace.json version \(configuration.version)")
            }

            let names = configuration.repositories.map(\.name)
            guard Set(names).count == names.count else {
                throw .configuration("Workspace.json contains duplicate repository names")
            }

            return configuration
        }
    }
}
