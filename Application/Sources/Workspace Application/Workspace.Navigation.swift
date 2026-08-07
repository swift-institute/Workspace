public import File_System
public import Git_Foundation

extension Workspace {
    /// Reproducible local tooling for cclsp-backed Swift navigation.
    ///
    /// cclsp remains a third-party TypeScript tool. Workspace owns only the
    /// installation boundary, generated configuration, and SourceKit-LSP
    /// launch policy needed to use that tool against this checkout.
    public struct Navigation: Sendable {
        public let root: Workspace.Root
        public let configuration: Workspace.Configuration
        public let client: Git.Client

        public init(
            root: Workspace.Root,
            configuration: Workspace.Configuration,
            client: Git.Client = .init()
        ) {
            self.root = root
            self.configuration = configuration
            self.client = client
        }
    }
}

extension Workspace.Navigation {
    /// Public fork containing the SourceKit-LSP adapter and byte-framing fix.
    public static let repository =
        "https://github.com/swift-institute/cclsp.git"

    /// Published development line carrying the Institute integration.
    public static let branch = "sourcekit-lsp-adapter"

    /// Exact source revision used by generated navigation state.
    public static let revision =
        "155344c587d9a94dee8edb36fbb2b31693930b22"

    static let revisionComponent: File.Path.Component =
        "155344c587d9a94dee8edb36fbb2b31693930b22"

    static let installedBranch = "workspace-pinned"

    public var state: File.Directory {
        root.hierarchy[directory: ".workspace"][directory: "navigation"]
    }

    public var tools: File.Directory {
        root.hierarchy[directory: ".workspace"][directory: "tools"]
    }

    public var source: File.Directory {
        tools[directory: "cclsp"][directory: Self.revisionComponent]
    }

    public var executable: File {
        source[directory: "dist"][file: "index.js"]
    }

    public var configurationFile: File {
        state[file: "cclsp.json"]
    }

    public var descriptorFile: File {
        state[file: "mcp-server.json"]
    }

    public var workspaceExecutable: File {
        root.checkout[directory: "Application"][directory: ".build"][directory: "debug"][
            file: "institute"
        ]
    }
}
