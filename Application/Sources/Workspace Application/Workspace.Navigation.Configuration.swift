public import File_System
private import JSON

extension Workspace.Navigation {
    /// Package roots represented in the generated cclsp configuration.
    ///
    /// The Application package is always present. Inventory repositories are
    /// included only when they are materialized at their Workspace-derived
    /// sibling location and contain a manifest. No filesystem scan or name
    /// inference participates in this list.
    public func packageRoots() throws(Workspace.Error) -> [File.Directory] {
        let application = root.checkout[directory: "Application"]
        guard application[file: "Package.swift"].stat.isFile else {
            throw .configuration("Workspace Application has no Package.swift at \(application)")
        }

        var roots = [application]
        for repository in configuration.repositories {
            let directory = try root.materialization(for: repository)
            guard File(directory.path).stat.isDirectory else { continue }
            guard directory[file: "Package.swift"].stat.isFile else { continue }
            roots.append(directory)
        }
        return roots
    }

    /// Renders the exact cclsp configuration for the currently materialized
    /// Workspace inventory.
    public func renderedConfiguration() throws(Workspace.Error) -> Swift.String {
        let command = [
            workspaceExecutable.description,
            "navigation",
            "serve",
            "--workspace-path",
            root.checkout.description,
        ]
        let servers: [JSON] = try packageRoots().map { directory in
            [
                "command": command.json,
                "extensions": ["swift"].json,
                "rootDir": directory.description.json,
            ]
        }
        let document: JSON = ["servers": servers.json]
        return document.jsonString(pretty: true, sortKeys: true) + "\n"
    }

    /// Renders a client-neutral stdio MCP descriptor. MCP clients may store
    /// this shape differently, but command, arguments, and environment remain
    /// identical.
    public func renderedDescriptor() -> Swift.String {
        let document: JSON = [
            "args": [executable.description].json,
            "command": "node",
            "env": [
                "CCLSP_CONFIG_PATH": configurationFile.description.json
            ].json,
            "type": "stdio",
        ]
        return document.jsonString(pretty: true, sortKeys: true) + "\n"
    }
}
