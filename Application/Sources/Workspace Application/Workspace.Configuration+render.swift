import JSON

extension Workspace.Configuration {
    public func rendered() throws(Workspace.Error) -> Swift.String {
        let configuration = try validated()
        let output = configuration.jsonString(pretty: true, sortKeys: true) + "\n"
        let decoded: Self
        do throws(JSON.Error) {
            decoded = try Self(jsonString: output)
        } catch {
            throw .configuration("generated Institute.json is invalid: \(error)")
        }
        guard try decoded.validated() == configuration else {
            throw .configuration("generated Institute.json does not round-trip")
        }
        return output
    }
}
