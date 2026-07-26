private import JSON

extension Workspace.Doctor.Pin {
    /// One pin as the resolved-state file records it, before its branch
    /// tip is probed.
    public struct Record: Equatable, Sendable {
        public let dependency: Swift.String
        public let location: Swift.String
        public let branch: Swift.String
        public let revision: Swift.String

        public init(
            dependency: Swift.String,
            location: Swift.String,
            branch: Swift.String,
            revision: Swift.String
        ) {
            self.dependency = dependency
            self.location = location
            self.branch = branch
            self.revision = revision
        }
    }
}

extension Workspace.Doctor.Pin.Record {
    /// The branch-pinned records in a resolved-state document
    /// (`Package.resolved`, format versions 2 and 3).
    ///
    /// Version pins carry no branch to probe and cannot go stale
    /// against a tip, so they are not part of the stale-pin population.
    /// The branch key alone discriminates — a branch name may be
    /// version-shaped, so the value is never sniffed. A document
    /// without a `pins` array, or a pin missing its identity, location,
    /// or revision, is unparseable and throws — never an empty result.
    public static func parse(_ source: Swift.String) throws(Workspace.Error) -> [Self] {
        let document: JSON
        do throws(JSON.Error) {
            document = try JSON.parse(source)
        } catch {
            throw .configuration("resolved state is not JSON: \(error)")
        }
        guard let pins = document.dictionary?["pins"]?.array else {
            throw .configuration("resolved state carries no pins array")
        }
        var records = [Self]()
        for pin in pins {
            guard
                let object = pin.dictionary,
                let dependency = text(object["identity"]),
                let location = text(object["location"]),
                let state = object["state"]?.dictionary,
                let revision = text(state["revision"])
            else {
                throw .configuration(
                    "a pin record is missing its identity, location, or revision"
                )
            }
            guard let branch = text(state["branch"]) else { continue }
            records.append(
                .init(
                    dependency: dependency,
                    location: location,
                    branch: branch,
                    revision: revision
                )
            )
        }
        return records
    }

    /// The value as a string, or `nil` when absent or not a string —
    /// absence is a case the caller decides on, not an error.
    private static func text(_ value: JSON?) -> Swift.String? {
        guard let value else { return nil }
        do throws(JSON.Error) {
            return try Swift.String(json: value)
        } catch {
            return nil
        }
    }
}
