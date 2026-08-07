public import File_System

extension Workspace.Inventory {
    public struct Writer: Sendable {
        public let root: File.Directory

        public init(root: File.Directory) {
            self.root = root
        }
    }
}

extension Workspace.Inventory.Writer {
    public func plan(
        _ configuration: Workspace.Configuration
    ) throws(Workspace.Error) -> Plan {
        let output = try configuration.rendered()
        let file = root[file: "Institute.json"]
        guard file.stat.exists else { return .replace(output) }
        return try read(file) == [Byte](output.utf8) ? .current : .replace(output)
    }

    public func run(
        _ configuration: Workspace.Configuration,
        replacing document: Workspace.Configuration.Document
    ) throws(Workspace.Error) -> Plan {
        let plan = try plan(configuration)
        guard case .replace(let output) = plan else { return plan }

        let file = root[file: "Institute.json"]
        guard file.stat.exists, try read(file) == document.bytes else {
            throw .changed
        }
        do throws(File.System.Write.Atomic.Error) {
            try file.write.atomic(output)
        } catch {
            throw .filesystem("cannot replace \(file): \(error)")
        }
        return plan
    }

    private func read(_ file: File) throws(Workspace.Error) -> [Byte] {
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try file.read.full { bytes in
                var storage = [Byte]()
                storage.reserveCapacity(bytes.count)
                for index in bytes.indices {
                    storage.append(bytes[index])
                }
                return storage
            }
        } catch {
            throw .filesystem("cannot read \(file): \(error)")
        }
    }
}
