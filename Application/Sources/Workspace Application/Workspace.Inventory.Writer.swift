public import File_System

extension Workspace.Inventory {
    public struct Writer: Sendable {
        public let root: File.Directory

        public init(root: File.Directory) {
            self.root = root
        }

        public func plan(
            _ configuration: Workspace.Configuration
        ) throws(Workspace.Error) -> Plan {
            let output = try configuration.rendered()
            let file = root[file: "Workspace.json"]
            guard file.stat.exists else { return .replace(output) }

            let current: Swift.String
            do throws(File.System.Read.Full.Error) {
                current = try file.read.full { bytes in
                    var storage = [Byte]()
                    storage.reserveCapacity(bytes.count)
                    for index in 0..<bytes.count {
                        storage.append(bytes[index])
                    }
                    return Swift.String(decoding: storage, as: Swift.UTF8.self)
                }
            } catch {
                throw .filesystem("cannot read \(file): \(error)")
            }
            return current == output ? .current : .replace(output)
        }

        public func run(
            _ configuration: Workspace.Configuration,
            dry: Bool
        ) throws(Workspace.Error) -> Plan {
            let plan = try plan(configuration)
            guard case .replace(let output) = plan, !dry else { return plan }

            let file = root[file: "Workspace.json"]
            do throws(File.System.Write.Atomic.Error) {
                try file.write.atomic(output)
            } catch {
                throw .filesystem("cannot replace \(file): \(error)")
            }
            return plan
        }
    }
}
