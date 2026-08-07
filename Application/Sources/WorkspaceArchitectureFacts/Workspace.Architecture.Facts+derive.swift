public import File_System
private import JSON
public import WorkspaceArchitectureModel

extension Workspace.Architecture.Facts {
    /// Derives the model from a Workspace checkout on disk.
    ///
    /// The inventory is read from `Workspace.json` at the checkout root;
    /// manifests are read from sibling organization checkouts
    /// (`<institute>/<organization>/<name>/Package.swift`) where present.
    /// An absent checkout is not an error — its row still yields a fact
    /// and a provenance edge; only manifest-derived detail is missing.
    public static func derive(at root: File.Directory) throws(Error) -> Self {
        let inventoryText = try text(of: root[file: "Workspace.json"])
        let inventory: Inventory
        do throws(JSON.Error) {
            inventory = try .init(jsonString: inventoryText)
        } catch {
            throw .undecodableInventory("\(error)")
        }

        let rootPath = "\(root)"
        let institutePath: Swift.String
        if let separator = rootPath.lastIndex(of: "/") {
            institutePath = Swift.String(rootPath[..<separator])
        } else {
            institutePath = rootPath
        }

        var manifests: [Workspace.Architecture.Owner: Manifest] = [:]
        for row in inventory.rows {
            let packagePath = "\(institutePath)/\(row.organization)/\(row.name)"
            let directory: File.Directory
            do throws(File.Path.Error) {
                directory = try File.Directory(validating: packagePath)
            } catch {
                continue
            }
            do throws(Error) {
                manifests[row.owner] = Manifest.scan(
                    try text(of: directory[file: "Package.swift"])
                )
            } catch {
                // An absent or unreadable manifest is a fact about the local
                // checkout, not a derivation failure.
                continue
            }
        }
        return derive(inventory: inventory, manifests: manifests)
    }

    private static func text(of file: File) throws(Error) -> Swift.String {
        do throws(Either<File.System.Read.Full.Error, Never>) {
            let bytes = try file.read.full { (span) in
                var storage = [Byte]()
                storage.reserveCapacity(span.count)
                for index in span.indices {
                    storage.append(span[index])
                }
                return storage
            }
            return Swift.String(decoding: bytes, as: Swift.UTF8.self)
        } catch {
            throw .unreadableFile(path: "\(file)", reason: "\(error)")
        }
    }
}
