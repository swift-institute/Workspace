private import Build_Coordinator
public import Command
private import Environment
private import File_System
private import GitHub_HTTP
private import Git_Foundation
private import JSON
private import Process

#if canImport(Darwin)
    private import Darwin
#elseif canImport(Glibc)
    private import Glibc
#elseif canImport(Musl)
    private import Musl
#endif

extension Workspace {
    public struct CLI: Sendable, Command.`Protocol` {
        public var operation: Operation
        public var dry: Bool
        public var consumer: Swift.String
        public var dependency: Swift.String
        public var modes: [Mode]
        public var packagePath: Swift.String
        public var workspacePath: Swift.String
        public var fresh: Bool
        public var changed: Bool
        public var fix: Bool
        public var institute: Bool
        public var output: Workspace.Dependency.Output?
        public var sanctionedExceptions: [Swift.String]
        public var arguments: [Swift.String]
        public var buildPath: Workspace.Coherence.BuildPath?
        public var receiptPath: Swift.String
        public var jobs: Swift.Int?
        public var organization: Swift.String
        public var permissions: [Swift.String]
        public var applicationIdentity: Swift.String
        public var keyPath: Swift.String
        public var issue: Swift.String
        public var maxBytes: Swift.Int
        public var includedComments: [Swift.String]
        public var dispositions: [Swift.String]
        public var verifications: [Swift.String]
        public var claimedHead: Swift.String
        public var defaultBranch: Swift.String
        public var verificationVisibility: Swift.String
        public var verificationLayer: Swift.String
        public var inventoryDigest: Swift.String
        public var inventoryScope: Swift.String
        public var inventoryOutput: Swift.String
        public var workspaceRevision: Swift.String
        public var policyRevision: Swift.String
        public var requestedOperations: [Swift.String]
        public var requiredOperations: [Swift.String]
        public var platformSupport: [Swift.String]

        public init(
            operation: Operation = .sync,
            dry: Bool = false,
            consumer: Swift.String = "",
            dependency: Swift.String = "",
            modes: [Mode] = [],
            packagePath: Swift.String = "",
            workspacePath: Swift.String = "",
            fresh: Bool = false,
            changed: Bool = false,
            fix: Bool = false,
            institute: Bool = false,
            output: Workspace.Dependency.Output? = nil,
            sanctionedExceptions: [Swift.String] = [],
            arguments: [Swift.String] = [],
            buildPath: Workspace.Coherence.BuildPath? = nil,
            receiptPath: Swift.String = "",
            jobs: Swift.Int? = nil,
            organization: Swift.String = "",
            permissions: [Swift.String] = [],
            applicationIdentity: Swift.String = "",
            keyPath: Swift.String = "",
            issue: Swift.String = "",
            maxBytes: Swift.Int = 24_000,
            includedComments: [Swift.String] = [],
            dispositions: [Swift.String] = [],
            verifications: [Swift.String] = [],
            claimedHead: Swift.String = "",
            defaultBranch: Swift.String = "",
            verificationVisibility: Swift.String = "",
            verificationLayer: Swift.String = "",
            inventoryDigest: Swift.String = "",
            inventoryScope: Swift.String = "",
            inventoryOutput: Swift.String = "",
            workspaceRevision: Swift.String = "",
            policyRevision: Swift.String = "",
            requestedOperations: [Swift.String] = [],
            requiredOperations: [Swift.String] = [],
            platformSupport: [Swift.String] = []
        ) {
            self.operation = operation
            self.dry = dry
            self.consumer = consumer
            self.dependency = dependency
            self.modes = modes
            self.packagePath = packagePath
            self.workspacePath = workspacePath
            self.fresh = fresh
            self.changed = changed
            self.fix = fix
            self.institute = institute
            self.output = output
            self.sanctionedExceptions = sanctionedExceptions
            self.arguments = arguments
            self.buildPath = buildPath
            self.receiptPath = receiptPath
            self.jobs = jobs
            self.organization = organization
            self.permissions = permissions
            self.applicationIdentity = applicationIdentity
            self.keyPath = keyPath
            self.issue = issue
            self.maxBytes = maxBytes
            self.includedComments = includedComments
            self.dispositions = dispositions
            self.verifications = verifications
            self.claimedHead = claimedHead
            self.defaultBranch = defaultBranch
            self.verificationVisibility = verificationVisibility
            self.verificationLayer = verificationLayer
            self.inventoryDigest = inventoryDigest
            self.inventoryScope = inventoryScope
            self.inventoryOutput = inventoryOutput
            self.workspaceRevision = workspaceRevision
            self.policyRevision = policyRevision
            self.requestedOperations = requestedOperations
            self.requiredOperations = requiredOperations
            self.platformSupport = platformSupport
        }
    }
}

extension Workspace.CLI {
    public static var configuration: Command.Configuration {
        .init(
            name: "workspace",
            abstract: "Synchronize, diagnose, and operate the public Swift Institute workspace."
        )
    }

    public static var schema: Command.Schema.Definition<Self> {
        Command.Schema.Definition<Self> {
            Command.Positional(
                \.operation,
                name: "operation",
                placeholder:
                    "install|sync|build|doctor|inventory|dependencies|compose|restore|verify|context"
                    + "|navigation|package|lint|coherence|conversion|github|verification",
                help: .init(abstract: "Operation to perform.")
            )
            Command.Positional<Self, Mode>.Many(
                \.modes,
                name: "mode",
                placeholder:
                    "install|check|packet|serve|build|test|run|resolve|update|regenerate|effective|clean|dump-package"
                    + "|lint|ledger|pages|seal|token",
                arity: .atMost(1),
                help: .init(
                    abstract:
                        "Required after context, navigation, package, conversion, or github; "
                        + "optional after inventory or lint. Use lint ledger for the complete "
                        + "residual compliance report."
                )
            )
            Command.Flag(
                \.dry,
                name: .long(.literal("dry-run")),
                help: .init(
                    abstract:
                        "Plan synchronization or inventory regeneration without changing files "
                        + "or Git metadata."
                )
            )
            Command.Flag(
                \.fresh,
                name: .long(.literal("fresh")),
                help: .init(
                    abstract:
                        "Use isolated build state — a scratch directory for a package build or "
                        + "test, a derived-data directory for the workspace build."
                )
            )
            Command.Flag(
                \.changed,
                name: .long(.literal("changed")),
                help: .init(
                    abstract:
                        "Sweep only packages with local work — an unclean worktree, or commits not "
                        + "yet in the tracked upstream (lint sweep only)."
                )
            )
            Command.Flag(
                \.fix,
                name: .long(.literal("fix")),
                help: .init(
                    abstract:
                        "Apply the canonical fix of every rewriter-backed rule instead of "
                        + "reporting findings (lint sweep or package lint). Add --dry-run to "
                        + "print the diffs without writing."
                )
            )
            Command.Flag(
                \.institute,
                name: .long(.literal("institute")),
                help: .init(
                    abstract:
                        "Run the institute-internal doctor checks too, which discover the live "
                        + "GitHub organizations (needs an authenticated gh; ~460 requests)."
                )
            )
            Command.Option(
                \.output,
                name: .long(.literal("format")),
                placeholder: "human|json",
                help: .init(
                    abstract:
                        "Render a concise human summary or deterministic JSON "
                        + "(dependencies, context packet, or lint ledger; defaults to human)."
                )
            )
            Command.Option(
                \.issue,
                name: .long(.literal("issue")),
                placeholder: "owner/repository#N",
                help: .init(abstract: "Issue whose current context is rendered (context packet only).")
            )
            Command.Option(
                \.maxBytes,
                name: .long(.literal("max-bytes")),
                placeholder: "n",
                help: .init(abstract: "Maximum rendered packet bytes (context packet only; defaults to 24000).")
            )
            Command.Option<Self, Swift.String>.Many(
                \.includedComments,
                name: .long(.literal("include-comment")),
                placeholder: "URL",
                help: .init(abstract: "Explicit Issue comment URL to include (context packet only; repeatable).")
            )
            Command.Option<Self, Swift.String>.Many(
                \.dispositions,
                name: .long(.literal("disposition")),
                placeholder: "rule=state@owner/repository#N",
                help: .init(
                    abstract:
                        "Supply one terminal advisory disposition and exact owner Issue "
                        + "(lint ledger only; repeatable)."
                )
            )
            Command.Option<Self, Swift.String>.Many(
                \.verifications,
                name: .long(.literal("verification")),
                placeholder: "owner/repository@sha=actions-run-url",
                help: .init(
                    abstract:
                        "Supply one exact-head successful GitHub Actions coordinate "
                        + "(lint ledger only; repeatable)."
                )
            )
            Command.Option<Self, Swift.String>.Many(
                \.sanctionedExceptions,
                name: .long(.literal("sanctioned-exception")),
                placeholder: "owner/repository",
                help: .init(
                    abstract:
                        "Classify this canonical repository identity as a policy-supplied "
                        + "sanctioned exception (dependencies only; repeatable)."
                )
            )
            Command.Option(
                \.consumer,
                name: .long(.literal("consumer")),
                placeholder: "repository",
                help: .init(
                    abstract: "Workspace repository whose manifest is composed (compose/restore/verify)."
                )
            )
            Command.Option(
                \.dependency,
                name: .long(.literal("dependency")),
                placeholder: "repository",
                help: .init(
                    abstract: "Workspace repository redirected to a local source (compose/restore/verify)."
                )
            )
            Command.Option(
                \.packagePath,
                name: .long(.literal("package-path")),
                placeholder: "path",
                help: .init(
                    abstract: "Package root for a package operation (defaults to PWD)."
                )
            )
            Command.Option(
                \.workspacePath,
                name: .long(.literal("workspace-path")),
                placeholder: "path",
                help: .init(
                    abstract: "Workspace checkout a navigation or lint invocation resolves against."
                )
            )
            Command.Option<Self, Swift.String>.Many(
                \.arguments,
                name: .long(.literal("argument")),
                placeholder: "swiftpm-argument",
                help: .init(
                    abstract:
                        "Argument forwarded to the underlying tool (repeatable) — SwiftPM for a "
                        + "package operation, xcodebuild for the workspace build."
                )
            )
            Command.Option(
                \.jobs,
                name: .long(.literal("jobs")),
                placeholder: "n",
                help: .init(
                    abstract:
                        "Cap compile jobs the coordinator gives SwiftPM (package build or test "
                        + "only); defaults to the machine's processor count."
                )
            )
            Command.Option(
                \.buildPath,
                name: .long(.literal("build-path")),
                placeholder: "xcodebuild-merged|swiftpm-composed-root",
                help: .init(
                    abstract:
                        "Which build path measures coherence (defaults to xcodebuild-merged, "
                        + "issue #80); swiftpm-composed-root is the Ubuntu-capable Phase 2 path "
                        + "(issue #81)."
                )
            )
            Command.Option(
                \.receiptPath,
                name: .long(.literal("receipt")),
                placeholder: "path",
                help: .init(
                    abstract:
                        "Conversion receipt file `conversion check` re-reads (issue #83); "
                        + "`verification seal`'s output path or `verification check`'s input path "
                        + "(#253)."
                )
            )
            Command.Option(
                \.claimedHead,
                name: .long(.literal("claimed-head")),
                placeholder: "40-hex-sha",
                help: .init(
                    abstract:
                        "The commit the caller believes the subject checkout stands on "
                        + "(verification seal only); refused if it does not match the checked-out "
                        + "HEAD."
                )
            )
            Command.Option(
                \.defaultBranch,
                name: .long(.literal("default-branch")),
                placeholder: "name",
                help: .init(
                    abstract:
                        "The subject repository's default branch, as the caller resolved it "
                        + "(verification seal only)."
                )
            )
            Command.Option(
                \.verificationVisibility,
                name: .long(.literal("visibility")),
                placeholder: "public|private|unmeasured",
                help: .init(
                    abstract: "The subject repository's visibility, as the caller resolved it "
                        + "(verification seal only); never interrogated live."
                )
            )
            Command.Option(
                \.verificationLayer,
                name: .long(.literal("layer")),
                placeholder: "primitives|standards|foundations|components|applications",
                help: .init(
                    abstract:
                        "The subject's effective-inventory layer, as the caller resolved it "
                        + "(verification seal only)."
                )
            )
            Command.Option(
                \.inventoryDigest,
                name: .long(.literal("inventory-digest")),
                placeholder: "hex",
                help: .init(
                    abstract:
                        "The effective Workspace inventory digest measuring this run "
                        + "(verification seal only); see `Workspace.Inventory.Effective` (#132)."
                )
            )
            Command.Option(
                \.inventoryScope,
                name: .long(.literal("inventory-scope")),
                placeholder: "public|effective",
                help: .init(
                    abstract:
                        "The population breadth the effective-inventory report covers "
                        + "(inventory effective only): the committed public roster alone, or "
                        + "combined with one authorized private discovery pass."
                )
            )
            Command.Option(
                \.inventoryOutput,
                name: .long(.literal("inventory-output")),
                placeholder: "path",
                help: .init(
                    abstract:
                        "Where the effective-inventory report is written atomically "
                        + "(inventory effective only)."
                )
            )
            Command.Option(
                \.workspaceRevision,
                name: .long(.literal("workspace-revision")),
                placeholder: "40-hex-sha",
                help: .init(
                    abstract:
                        "The Workspace source/executable revision performing this run "
                        + "(verification seal only)."
                )
            )
            Command.Option(
                \.policyRevision,
                name: .long(.literal("policy-revision")),
                placeholder: "revision",
                help: .init(
                    abstract:
                        "The control plane's universal policy/fixture revision this run measures "
                        + "against (verification seal only)."
                )
            )
            Command.Option<Self, Swift.String>.Many(
                \.requestedOperations,
                name: .long(.literal("step")),
                placeholder: "build|test|nested-tests|lint",
                help: .init(
                    abstract:
                        "One operation to perform (verification seal only; repeatable; defaults "
                        + "to build, test, and lint)."
                )
            )
            Command.Option<Self, Swift.String>.Many(
                \.requiredOperations,
                name: .long(.literal("required-step")),
                placeholder: "build|test|nested-tests|lint",
                help: .init(
                    abstract:
                        "One operation whose absence or non-execution refuses the seal "
                        + "(verification seal only; repeatable; defaults to every --step)."
                )
            )
            Command.Option<Self, Swift.String>.Many(
                \.platformSupport,
                name: .long(.literal("platform-support")),
                placeholder: "name",
                help: .init(
                    abstract:
                        "One declared supported-platform name, carried verbatim "
                        + "(verification seal only; repeatable)."
                )
            )
            Command.Option(
                \.organization,
                name: .long(.literal("org")),
                placeholder: "organization",
                help: .init(
                    abstract: "GitHub organization whose installation token is minted (github token)."
                )
            )
            Command.Option<Self, Swift.String>.Many(
                \.permissions,
                name: .long(.literal("permission")),
                placeholder: "name=level",
                help: .init(
                    abstract:
                        "Narrow the minted token to this permission (github token; repeatable). "
                        + "Without one the token carries the installation's whole grant."
                )
            )
            Command.Option(
                \.applicationIdentity,
                name: .long(.literal("app-id")),
                placeholder: "identity",
                help: .init(
                    abstract:
                        "GitHub App identity to mint as; defaults to GITHUB_APP_ID, then the "
                        + "identity file in the configuration directory."
                )
            )
            Command.Option(
                \.keyPath,
                name: .long(.literal("key")),
                placeholder: "path",
                help: .init(
                    abstract:
                        "Signing key to use; defaults to GITHUB_APP_PRIVATE_KEY_PATH, then the "
                        + "sole .pem in the configuration directory."
                )
            )
        }
    }

    public mutating func validate() throws(Command.Error) {
        // Rejected rather than ignored, for the same reason `--institute` is:
        // a credential flag silently dropped mints a *wider* token than the
        // caller asked for, and nothing downstream can tell the difference.
        guard
            operation == .github
                || (organization.isEmpty && permissions.isEmpty && applicationIdentity.isEmpty
                    && keyPath.isEmpty)
        else {
            throw .validationFailed(
                reason: "--org, --permission, --app-id, and --key are valid only with github token."
            )
        }
        guard
            (operation == .context && modes.first == .packet)
                || (issue.isEmpty && maxBytes == 24_000 && includedComments.isEmpty)
        else {
            throw .validationFailed(
                reason: "--issue, --max-bytes, and --include-comment are valid only with context packet."
            )
        }
        guard operation == .lint || !changed else {
            throw .validationFailed(reason: "--changed is valid only with the lint sweep.")
        }
        // Rejected rather than ignored, for the reason every flag here is:
        // a `--fix` that was silently dropped would leave the caller reading
        // a findings report and believing it was a record of what had just
        // been repaired.
        guard operation == .lint || (operation == .package && modes.first == .lint) || !fix else {
            throw .validationFailed(
                reason: "--fix is valid only with the lint sweep or `package lint`."
            )
        }
        // Rejected rather than ignored: a flag that asks for a measurement
        // and is silently dropped produces a report that looks like the one
        // that measured, which is the defect `--institute` exists to fix.
        guard operation == .doctor || !institute else {
            throw .validationFailed(reason: "--institute is valid only with doctor.")
        }
        guard operation == .coherence || buildPath == nil else {
            throw .validationFailed(reason: "--build-path is valid only with coherence.")
        }
        // Only build and test ever reach `Build.Action.acceptsJobs`; a cap
        // silently accepted anywhere else would look like it did something.
        guard
            jobs == nil
                || (operation == .package
                    && (modes.first?.buildAction == .build || modes.first?.buildAction == .test))
        else {
            throw .validationFailed(reason: "--jobs is valid only with package build or test.")
        }
        let ledger = operation == .lint && modes.first == .ledger
        guard
            operation == .dependencies
                || (operation == .context && modes.first == .packet)
                || ledger
                || (output == nil && sanctionedExceptions.isEmpty)
        else {
            throw .validationFailed(
                reason:
                    "--format is valid only with dependencies, context packet, or lint ledger; "
                    + "--sanctioned-exception is valid only with dependencies."
            )
        }
        guard operation == .dependencies || sanctionedExceptions.isEmpty else {
            throw .validationFailed(reason: "--sanctioned-exception is valid only with dependencies.")
        }
        guard ledger || (dispositions.isEmpty && verifications.isEmpty) else {
            throw .validationFailed(
                reason: "--disposition and --verification are valid only with lint ledger."
            )
        }
        if operation == .dependencies {
            guard modes.isEmpty else {
                throw .validationFailed(reason: "dependencies takes no mode.")
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with dependencies."
                )
            }
            guard !dry, !fresh, !changed, !institute else {
                throw .validationFailed(
                    reason:
                        "--dry-run, --fresh, --changed, and --institute are not valid with dependencies."
                )
            }
            guard packagePath.isEmpty, workspacePath.isEmpty, arguments.isEmpty else {
                throw .validationFailed(
                    reason:
                        "--package-path, --workspace-path, and --argument are not valid with dependencies."
                )
            }
            var exceptions = Set<Workspace.Repository.Key>()
            for value in sanctionedExceptions {
                guard let key = Workspace.Repository.Key(identity: value) else {
                    throw .validationFailed(
                        reason: "invalid sanctioned exception \(value); expected owner/repository."
                    )
                }
                guard exceptions.insert(key).inserted else {
                    throw .validationFailed(
                        reason: "duplicate sanctioned exception \(value)."
                    )
                }
            }
        } else if operation == .install {
            guard modes.isEmpty else {
                throw .validationFailed(reason: "install takes no mode.")
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with install."
                )
            }
            guard !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !fresh else {
                throw .validationFailed(reason: "--fresh is valid only with package build or test.")
            }
            guard packagePath.isEmpty else {
                throw .validationFailed(reason: "--package-path is valid only with package.")
            }
            guard workspacePath.isEmpty else {
                throw .validationFailed(
                    reason: "--workspace-path is valid only with navigation or lint."
                )
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        } else if operation == .context {
            guard
                modes.count == 1,
                modes.first == .install || modes.first == .check || modes.first == .packet
            else {
                throw .validationFailed(reason: "context requires install, check, or packet.")
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with context."
                )
            }
            guard !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !fresh else {
                throw .validationFailed(reason: "--fresh is valid only with package build or test.")
            }
            guard packagePath.isEmpty else {
                throw .validationFailed(reason: "--package-path is valid only with package.")
            }
            guard workspacePath.isEmpty else {
                throw .validationFailed(reason: "--workspace-path is valid only with navigation.")
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
            guard
                modes.first == .packet
                    || (issue.isEmpty && includedComments.isEmpty && maxBytes == 24_000)
            else {
                throw .validationFailed(
                    reason: "--issue, --max-bytes, and --include-comment are valid only with context packet."
                )
            }
            if modes.first == .packet {
                guard Workspace.Context.Packet.Key(argument: issue) != nil else {
                    throw .validationFailed(reason: "context packet requires --issue owner/repository#N.")
                }
                guard maxBytes >= 512 else {
                    throw .validationFailed(reason: "context packet --max-bytes must be at least 512.")
                }
            }
        } else if operation == .navigation {
            guard
                modes.count == 1,
                modes.first == .install || modes.first == .check || modes.first == .serve
            else {
                throw .validationFailed(reason: "navigation requires install, check, or serve.")
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with navigation."
                )
            }
            guard !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !fresh else {
                throw .validationFailed(reason: "--fresh is valid only with package build or test.")
            }
            guard packagePath.isEmpty else {
                throw .validationFailed(reason: "--package-path is valid only with package.")
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        } else if operation == .lint {
            guard
                modes.isEmpty || modes.first == .install || modes.first == .check
                    || modes.first == .ledger
            else {
                throw .validationFailed(
                    reason:
                        "lint takes install, check, ledger, or no mode (the ecosystem sweep)."
                )
            }
            guard modes.isEmpty || !changed else {
                throw .validationFailed(reason: "--changed is valid only with the lint sweep.")
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with lint."
                )
            }
            // `--fix --dry-run` is the preview of a fix run — the one place
            // `--dry-run` means something here, and the only place it does.
            guard !dry || fix else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !fresh else {
                throw .validationFailed(reason: "--fresh is valid only with package build or test.")
            }
            guard modes.first != .ledger || (!fix && !dry) else {
                throw .validationFailed(
                    reason: "lint ledger is read-only; --fix and --dry-run are not valid."
                )
            }
            if modes.first == .ledger {
                var dispositionRules = Swift.Set<Swift.String>()
                for value in dispositions {
                    guard let disposition = Workspace.Lint.Ledger.Disposition(argument: value)
                    else {
                        throw .validationFailed(
                            reason:
                                "invalid disposition \(value); expected "
                                + "rule=state@owner/repository#N."
                        )
                    }
                    guard dispositionRules.insert(disposition.rule).inserted else {
                        throw .validationFailed(
                            reason: "duplicate disposition for rule \(disposition.rule)."
                        )
                    }
                }
                var verificationRepositories = Swift.Set<Workspace.Repository.Key>()
                for value in verifications {
                    guard let verification = Workspace.Lint.Ledger.Verification(argument: value)
                    else {
                        throw .validationFailed(
                            reason:
                                "invalid verification \(value); expected "
                                + "owner/repository@<40-hex-sha>=<actions-run-url>."
                        )
                    }
                    guard verificationRepositories.insert(verification.repository).inserted else {
                        throw .validationFailed(
                            reason:
                                "duplicate verification for "
                                + "\(verification.repository.identity)."
                        )
                    }
                }
            }
            guard packagePath.isEmpty else {
                throw .validationFailed(
                    reason: "--package-path is valid only with package; lint sweeps the inventory."
                )
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        } else if operation == .package {
            guard modes.count == 1, let mode = modes.first else {
                throw .validationFailed(
                    reason:
                        "package requires build, test, run, resolve, update, clean, dump-package, or lint."
                )
            }
            let action = mode.buildAction
            guard action != nil || mode == .lint else {
                throw .validationFailed(
                    reason:
                        "package requires build, test, run, resolve, update, clean, dump-package, or lint."
                )
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with package."
                )
            }
            // `--fix --dry-run` previews a `package lint --fix`; nothing else
            // in this branch has a plan to show.
            guard !dry || (fix && mode == .lint) else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !fresh || action == .build || action == .test else {
                throw .validationFailed(reason: "--fresh is valid only with package build or test.")
            }
            guard workspacePath.isEmpty else {
                throw .validationFailed(reason: "--workspace-path is valid only with navigation.")
            }
        } else if operation.composesADependency {
            guard modes.isEmpty else {
                throw .validationFailed(reason: "install and check are valid only after context.")
            }
            guard !consumer.isEmpty else {
                throw .validationFailed(reason: "\(operation.argumentDescription) requires --consumer.")
            }
            guard !dependency.isEmpty else {
                throw .validationFailed(reason: "\(operation.argumentDescription) requires --dependency.")
            }
            guard !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !fresh, packagePath.isEmpty, workspacePath.isEmpty else {
                throw .validationFailed(
                    reason: "--fresh, --package-path, and --workspace-path are not valid here."
                )
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        } else if operation == .inventory {
            guard
                modes.isEmpty
                    || (modes.count == 1
                        && (modes.first == .regenerate || modes.first == .pages
                            || modes.first == .effective))
            else {
                throw .validationFailed(
                    reason:
                        "inventory takes regenerate, pages, effective, or no mode (the read-only "
                        + "register)."
                )
            }
            guard modes.first == .effective || (inventoryScope.isEmpty && inventoryOutput.isEmpty)
            else {
                throw .validationFailed(
                    reason:
                        "--inventory-scope and --inventory-output are valid only with "
                        + "inventory effective."
                )
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with inventory."
                )
            }
            guard !dry || modes.first == .regenerate else {
                throw .validationFailed(
                    reason:
                        "--dry-run is valid only with inventory regenerate; inventory is already "
                        + "read-only."
                )
            }
            guard !fresh, packagePath.isEmpty, workspacePath.isEmpty else {
                throw .validationFailed(
                    reason: "--fresh, --package-path, and --workspace-path are not valid here."
                )
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        } else if operation == .conversion {
            guard
                modes.count == 1,
                modes.first == .seal || modes.first == .check
            else {
                throw .validationFailed(reason: "conversion requires seal or check.")
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with conversion."
                )
            }
            guard !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !fresh else {
                throw .validationFailed(reason: "--fresh is valid only with package build or test.")
            }
            guard packagePath.isEmpty, workspacePath.isEmpty else {
                throw .validationFailed(
                    reason: "--package-path and --workspace-path are not valid with conversion."
                )
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
            guard modes.first == .check || receiptPath.isEmpty else {
                throw .validationFailed(reason: "--receipt is valid only with conversion check.")
            }
            guard modes.first != .check || !receiptPath.isEmpty else {
                throw .validationFailed(reason: "conversion check requires --receipt.")
            }
        } else if operation == .github {
            guard modes.count == 1, modes.first == .token else {
                throw .validationFailed(reason: "github requires token.")
            }
            guard !organization.isEmpty else {
                throw .validationFailed(reason: "github token requires --org.")
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with github."
                )
            }
            guard !dry, !fresh else {
                throw .validationFailed(
                    reason: "--dry-run and --fresh are not valid with github."
                )
            }
            guard packagePath.isEmpty, workspacePath.isEmpty, arguments.isEmpty else {
                throw .validationFailed(
                    reason:
                        "--package-path, --workspace-path, and --argument are not valid with github."
                )
            }
        } else if operation == .build {
            guard modes.isEmpty else {
                throw .validationFailed(
                    reason: "build takes no mode; it builds the whole selection."
                )
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with build."
                )
            }
            guard !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard packagePath.isEmpty else {
                throw .validationFailed(
                    reason: "--package-path is valid only with package; build builds the selection."
                )
            }
            guard workspacePath.isEmpty else {
                throw .validationFailed(reason: "--workspace-path is valid only with navigation or lint.")
            }
        } else if operation == .coherence {
            guard modes.isEmpty else {
                throw .validationFailed(
                    reason: "coherence takes no mode; it measures the whole selection."
                )
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with coherence."
                )
            }
            guard !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !fresh else {
                throw .validationFailed(reason: "--fresh is valid only with package build or test.")
            }
            guard packagePath.isEmpty else {
                throw .validationFailed(
                    reason: "--package-path is valid only with package; coherence measures the selection."
                )
            }
            guard workspacePath.isEmpty else {
                throw .validationFailed(reason: "--workspace-path is valid only with navigation or lint.")
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        } else if operation == .verification {
            guard modes.count == 1, let mode = modes.first, mode == .seal || mode == .check else {
                throw .validationFailed(reason: "verification requires seal or check.")
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with verification."
                )
            }
            guard !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !receiptPath.isEmpty else {
                throw .validationFailed(
                    reason: "verification requires --receipt (seal's output path, check's input path)."
                )
            }
            if mode == .seal {
                guard !claimedHead.isEmpty else {
                    throw .validationFailed(reason: "verification seal requires --claimed-head.")
                }
                guard !defaultBranch.isEmpty else {
                    throw .validationFailed(reason: "verification seal requires --default-branch.")
                }
                guard Workspace.Verification.Visibility(rawValue: verificationVisibility) != nil else {
                    throw .validationFailed(
                        reason: "verification seal requires --visibility public, private, or unmeasured."
                    )
                }
                guard Workspace.Layer(rawValue: verificationLayer) != nil else {
                    throw .validationFailed(
                        reason:
                            "verification seal requires --layer primitives, standards, foundations, "
                            + "components, or applications."
                    )
                }
                guard !inventoryDigest.isEmpty else {
                    throw .validationFailed(reason: "verification seal requires --inventory-digest.")
                }
                guard !workspaceRevision.isEmpty else {
                    throw .validationFailed(reason: "verification seal requires --workspace-revision.")
                }
                guard !policyRevision.isEmpty else {
                    throw .validationFailed(reason: "verification seal requires --policy-revision.")
                }
                for value in requestedOperations + requiredOperations {
                    guard Workspace.Verification.Operation.Kind(rawValue: value) != nil else {
                        throw .validationFailed(
                            reason:
                                "\(value) is not build, test, nested-tests, or lint "
                                + "(--step/--required-step)."
                        )
                    }
                }
            } else {
                guard
                    packagePath.isEmpty, claimedHead.isEmpty, defaultBranch.isEmpty,
                    verificationVisibility.isEmpty,
                    verificationLayer.isEmpty, inventoryDigest.isEmpty, workspaceRevision.isEmpty,
                    policyRevision.isEmpty, requestedOperations.isEmpty, requiredOperations.isEmpty,
                    platformSupport.isEmpty, arguments.isEmpty, !fresh, jobs == nil
                else {
                    throw .validationFailed(reason: "verification check takes only --receipt.")
                }
            }
        } else {
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are valid only with compose, restore, or verify."
                )
            }
            guard operation == .sync || !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard modes.isEmpty else {
                throw .validationFailed(reason: "install and check are valid only after context.")
            }
            guard !fresh, packagePath.isEmpty, workspacePath.isEmpty else {
                throw .validationFailed(
                    reason: "--fresh, --package-path, and --workspace-path are not valid here."
                )
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        }
    }

    public mutating func run() async throws(Workspace.Error) {
        if case .install = operation {
            let installation = try Workspace.Installation()
            try installation.install()
            print("workspace: installed and verified")
            print("workspace command: \(installation.command)")
            print("workspace executable: \(installation.executable)")
            return
        }

        if case .github = operation, modes.first == .token {
            // Minting a credential has nothing to do with a Workspace
            // checkout, so this returns before any root is resolved: the
            // command works from any directory on the machine, which is what
            // makes `GH_TOKEN=$(workspace github token --org X)` usable in a
            // lane standing inside a package.
            let app: Workspace.GitHub.App
            let result: (token: Workspace.GitHub.App.Token, cached: Swift.Bool)
            do throws(Workspace.GitHub.App.Error) {
                app = try .resolve(
                    identity: applicationIdentity.isEmpty ? nil : applicationIdentity,
                    keyPath: keyPath.isEmpty ? nil : keyPath
                )
                result = try app.token(
                    organization: organization,
                    permissions: try permissions.map { (value) throws(Workspace.GitHub.App.Error) in
                        try .init(argument: value)
                    }
                )
            } catch {
                throw .configuration("github token: \(error)")
            }
            // The token is the whole of stdout, with no trailing commentary,
            // so command substitution captures a credential and nothing else.
            // Everything a human wants to know goes to stderr, where it cannot
            // end up inside an Authorization header.
            print(result.token.value)
            unsafe fputs(
                "github token: \(result.cached ? "cache hit" : "minted") for \(organization)\n",
                stderr
            )
            return
        }

        guard let working = Environment.read("PWD") else {
            throw .configuration("PWD is not available")
        }

        if case .package = operation, modes.first == .lint {
            // The inner-loop path. It reads no inventory, enumerates no
            // organisation, and constructs no `Workspace.Root`: standing
            // inside a package, the package root and the installed
            // binaries are both reachable by walking up. That is what
            // keeps this mode from paying ecosystem-scale costs.
            let target = try Workspace.Lint.Target.resolve(
                packagePath.isEmpty ? working : packagePath
            )
            let lint = try Workspace.Lint.resolve(from: target.package.description)
            // The default bundle comes from where the package sits under
            // the hierarchy the installation was found in — the same
            // ascent, no extra reads. It is used only when the package
            // carries no `Lint.swift`.
            let installation = try lint.installation()
            let mode: Workspace.Lint.Fix? = fix ? (dry ? .dryRun : .apply) : nil
            if mode != nil {
                guard Workspace.Lint.supportsFix(installation) else {
                    throw .configuration(Workspace.Lint.fixUnsupported)
                }
                // A refusal is reported as a measurement, never thrown.
                // Thrown, it left the report entirely: a lane saw
                // swift-format clean, swiftlint clean, and no swift-linter
                // line at all, and absence of a finding read as absence of
                // findings. As an UNMEASURED verdict it occupies the same
                // line, the same word, and the same exit code as every
                // other run that established nothing.
                if let reason = try lint.currency().reason {
                    let refused = Workspace.Lint.Measurement(
                        package: target.package.description,
                        verdict: .unmeasured(reason: reason),
                        summary: nil,
                        plan: nil,
                        findings: [],
                        structured: nil,
                        prerequisite: .currency,
                        diagnostics: "",
                        status: 0
                    )
                    print(refused)
                    Process.Exit.normal(2)
                }
                // The shadow gate, first tier only. The inner loop stands
                // inside one package and reads no inventory, so the
                // re-export tier — which needs the population to resolve a
                // module to the package providing it — has nothing to
                // resolve against and is not attempted. The sweep is where
                // it runs, and the sweep is what dispatches the fleet.
                let exclusions: [Swift.String]
                if let exclusion = Workspace.Lint.Shadow.exclusion(
                    for: Workspace.Lint.Shadow.scan(target.package)
                ) {
                    print("\(exclusion)")
                    print(
                        "          PLAT-ARCH-022 qualification is unsound here; "
                            + "it is excluded while other safe fixes proceed"
                    )
                    exclusions = [Workspace.Lint.Fix.shadowedStandardLibraryQualification]
                } else {
                    exclusions = []
                }
                let measurement = lint.measure(
                    target,
                    using: installation,
                    default: Workspace.Lint.Bundle.resolve(
                        target.package,
                        under: lint.hierarchy
                    ),
                    fix: mode,
                    excluding: exclusions
                )
                print(measurement)
                Process.Exit.normal(
                    measurement.verdict.fails ? (measurement.verdict.isUnmeasured ? 2 : 1) : 0
                )
            }
            let measurement = lint.measure(
                target,
                using: installation,
                default: Workspace.Lint.Bundle.resolve(
                    target.package,
                    under: lint.hierarchy
                ),
                fix: mode
            )
            print(measurement)
            Process.Exit.normal(measurement.verdict.fails ? (measurement.verdict.isUnmeasured ? 2 : 1) : 0)
        }

        if case .package = operation {
            guard let action = modes.first?.buildAction else {
                throw .configuration("package operation was not provided")
            }
            let status: Swift.Int32
            do throws(Build.Error) {
                status = try Build.Coordinator(jobs: jobs).run(
                    action,
                    at: packagePath.isEmpty ? working : packagePath,
                    fresh: fresh,
                    arguments: arguments
                )
            } catch {
                throw .process("\(error)")
            }
            Process.Exit.normal(status)
        }

        if case .verification = operation {
            // Any valid directory anchors the scratch file `digest(at:)`
            // places beside it, deleted before it returns — this is not
            // the ecosystem Workspace checkout, only a place to put a
            // transient sibling file. PWD is always available.
            let scratchDirectory: File.Directory
            do throws(File.Path.Error) {
                scratchDirectory = try File.Directory(validating: working)
            } catch {
                throw .configuration("PWD is not a valid directory: \(error)")
            }
            let scratchRoot = try Workspace.Root(checkout: scratchDirectory)

            switch modes.first {
            case .some(.seal):
                let subjectPath = packagePath.isEmpty ? working : packagePath
                let remote: Swift.String
                do throws(Git.Client.Error) {
                    remote = try Git.Client().remote("origin", at: subjectPath)
                } catch {
                    throw .process("cannot read the subject's origin remote at \(subjectPath): \(error)")
                }
                guard let coordinate = Workspace.Repository.Key(url: remote) else {
                    throw .configuration(
                        "origin remote \(remote) is not a canonical https://github.com/owner/name.git URL"
                    )
                }
                let requested =
                    requestedOperations.isEmpty
                    ? [Workspace.Verification.Operation.Kind.build, .test, .lint]
                    : requestedOperations.compactMap(Workspace.Verification.Operation.Kind.init(rawValue:))
                let required =
                    requiredOperations.isEmpty
                    ? requested
                    : requiredOperations.compactMap(Workspace.Verification.Operation.Kind.init(rawValue:))

                let run = Workspace.Verification.Run(
                    packagePath: subjectPath,
                    claimedHead: claimedHead,
                    coordinate: coordinate,
                    // `validate()` already refused an unrecognised value.
                    visibility: Workspace.Verification.Visibility(rawValue: verificationVisibility)!,
                    defaultBranch: defaultBranch,
                    layer: Workspace.Layer(rawValue: verificationLayer)!,
                    inventoryDigest: inventoryDigest,
                    workspaceRevision: workspaceRevision,
                    policyRevision: policyRevision,
                    requestedOperations: requested,
                    requiredOperations: required,
                    platformSupport: platformSupport,
                    fresh: fresh,
                    jobs: jobs,
                    arguments: arguments
                )
                let receipt: Workspace.Verification.Receipt
                do throws(Workspace.Verification.Error) {
                    receipt = try run.run()
                } catch {
                    throw .configuration("verification seal: \(error)")
                }

                let outputPath: File.Path
                do throws(File.Path.Error) {
                    outputPath = try File.Path(receiptPath)
                } catch {
                    throw .configuration("invalid --receipt path \(receiptPath): \(error)")
                }
                guard !File(outputPath).stat.exists else {
                    throw .configuration(
                        "--receipt \(receiptPath) already exists; verification seal writes only a "
                            + "newly created output path"
                    )
                }
                let outputFile = File(outputPath)
                // Untyped catch, deliberately: the async `atomic(_:options:)`
                // overload throws `Either<Kernel.Thread.Pool.Error,
                // File.System.Write.Atomic.Error>`, whose first member this
                // file has no reason to name or depend on directly — this
                // call site only needs "did the write succeed," which an
                // untyped `catch` reports exactly as well as spelling out
                // the union would.
                do {
                    try await outputFile.write.atomic(receipt.canonical)
                } catch {
                    throw .configuration("cannot write --receipt \(receiptPath): \(error)")
                }
                let digest = try? receipt.digest(at: scratchRoot)
                let summaryLine =
                    "verification seal: \(receipt.subject.coordinate.identity) "
                    + "\(receipt.verdict.fails ? "unverified" : "verified"), "
                    + "\(receipt.operations.count) operation(s)"
                    + (digest.map { ", digest \($0)" } ?? ", digest unavailable") + "\n"
                unsafe fputs(summaryLine, stderr)
                Process.Exit.normal(receipt.verdict.fails ? 1 : 0)
            case .some(.check):
                let inputPath: File.Path
                do throws(File.Path.Error) {
                    inputPath = try File.Path(receiptPath)
                } catch {
                    throw .configuration("invalid --receipt path \(receiptPath): \(error)")
                }
                let bytes: [Byte]
                do throws(Either<File.System.Read.Full.Error, Never>) {
                    bytes = try File.System.Read.Full.read(from: inputPath) { (span: Swift.Span<Byte>) in
                        var storage = [Byte]()
                        storage.reserveCapacity(span.count)
                        for index in span.indices {
                            storage.append(span[index])
                        }
                        return storage
                    }
                } catch {
                    throw .configuration("cannot read --receipt \(receiptPath): \(error)")
                }
                let receipt: Workspace.Verification.Receipt
                do throws(JSON.Error) {
                    receipt = try .init(jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self))
                } catch {
                    throw .configuration("cannot decode --receipt \(receiptPath): \(error)")
                }
                let diagnostics = Workspace.Verification.Check.diagnostics(for: receipt)
                guard diagnostics.isEmpty else {
                    throw .configuration(diagnostics.joined(separator: "\n"))
                }
                let digest = try? receipt.digest(at: scratchRoot)
                print(
                    "verification: current — \(receipt.subject.coordinate.identity) consistent"
                        + (digest.map { ", digest \($0)" } ?? ", digest unavailable")
                )
            default:
                throw .configuration("verification operation must be seal or check")
            }
            return
        }

        let checkoutValue =
            (operation == .navigation || operation == .lint) && !workspacePath.isEmpty
            ? workspacePath
            : working
        let checkout: File.Directory
        do throws(File.Path.Error) {
            checkout = try File.Directory(validating: checkoutValue)
        } catch {
            throw .configuration("Workspace checkout is not a valid path: \(error)")
        }
        let root = try Workspace.Root(checkout: checkout)

        if case .lint = operation {
            let lint = Workspace.Lint(root: root)
            switch modes.first {
            case .some(.install):
                // Install the installation `--fix` would resolve, not the
                // one this process happens to be standing next to. The two
                // rules disagreed — `--fix` ascends from the linted package,
                // `install` took the cwd's parent — so an install run from
                // anywhere else refreshed a different tree and reported
                // success while the lint run kept refusing on the tree it
                // had actually reached. Falling back to the checkout-derived
                // hierarchy keeps the first install on a fresh machine
                // working, where there is no installation to ascend to.
                let target = Workspace.Lint.existing(from: checkoutValue) ?? lint
                try target.install()
                let manifest = try target.installedManifest()
                print("lint: installed swift-linter \(manifest.digest)")
                print("lint: \(try target.executable(for: manifest))")
                // Always name the installation that was written. A success
                // line that does not say *which* installation is exactly
                // what let eight consecutive successful installs leave the
                // refusing tree untouched.
                print("lint: installation \(target.manifestFile)")
            case .some(.check):
                let diagnostics = try lint.diagnostics()
                guard diagnostics.isEmpty else {
                    throw .configuration(diagnostics.joined(separator: "\n"))
                }
                print("lint: current — digest \(try lint.installedManifest().digest) matches CI")
            case .some(.ledger):
                let dispositions = self.dispositions.compactMap(
                    Workspace.Lint.Ledger.Disposition.init(argument:)
                )
                let verifications = self.verifications.compactMap(
                    Workspace.Lint.Ledger.Verification.init(argument:)
                )
                let configuration = try Workspace.Configuration.load(at: root.checkout)
                let report = try await Workspace.Lint.Sweep(
                    lint: lint,
                    root: root,
                    repositories: configuration.repositories
                ).ledger(dispositions: dispositions, verifications: verifications)
                switch output ?? .human {
                case .human: print(report.description, terminator: "")
                case .json: print(report.json, terminator: "")
                }
                Process.Exit.normal(report.status)
            case nil:
                let fixMode: Workspace.Lint.Fix? = fix ? (dry ? .dryRun : .apply) : nil
                if fixMode != nil {
                    guard Workspace.Lint.supportsFix(try lint.installation()) else {
                        throw .configuration(Workspace.Lint.fixUnsupported)
                    }
                    // Same discipline as the single-package path: the
                    // sweep refuses in the sweep's own vocabulary rather
                    // than as a thrown error, so a reader scanning for
                    // UNMEASURED finds it and an exit code of 2 separates
                    // it from both 0 (clean) and 1 (violations).
                    if let reason = try lint.currency().reason {
                        print("lint all: UNMEASURED — \(reason)")
                        print(
                            "lint all: 0 packages linted; no repository in this sweep has been "
                                + "measured, and none may be recorded clean"
                        )
                        Process.Exit.normal(2)
                    }
                }
                let configuration = try Workspace.Configuration.load(at: root.checkout)
                let report = try await Workspace.Lint.Sweep(
                    lint: lint,
                    root: root,
                    repositories: configuration.repositories
                ).run(scope: changed ? .changed : .all, fix: fixMode)
                print(report)
                Process.Exit.normal(report.status)
            default:
                throw .configuration("lint operation must be install, check, ledger, or absent")
            }
            return
        }

        if case .navigation = operation {
            switch modes.first {
            case .some(.install):
                let configuration = try Workspace.Configuration.load(at: root.checkout)
                let navigation = Workspace.Navigation(
                    root: root,
                    configuration: configuration
                )
                try navigation.install()
                print("navigation: installed and verified")
                print("navigation MCP descriptor: \(navigation.descriptorFile)")
            case .some(.check):
                let configuration = try Workspace.Configuration.load(at: root.checkout)
                let navigation = Workspace.Navigation(
                    root: root,
                    configuration: configuration
                )
                let diagnostics = try navigation.diagnostics()
                guard diagnostics.isEmpty else {
                    throw .configuration(diagnostics.joined(separator: "\n"))
                }
                print("navigation: current")
            case .some(.serve):
                try Workspace.Navigation.serve()
            case nil:
                throw .configuration("navigation operation was not provided")
            default:
                throw .configuration("navigation operation must be install, check, or serve")
            }
            return
        }

        if case .context = operation {
            let context = try Workspace.Context(root: root)
            switch modes.first {
            case .some(.install):
                print(try context.install().summary)
            case .some(.check):
                let diagnostics = try context.diagnostics()
                guard diagnostics.isEmpty else {
                    throw .configuration(diagnostics.joined(separator: "\n"))
                }
                print("context: current")
            case .some(.packet):
                guard let key = Workspace.Context.Packet.Key(argument: issue) else {
                    throw .configuration("context packet requires --issue owner/repository#N.")
                }
                let result = await Workspace.Context.Packet.Remote.client().record(key, includedComments)
                let report: Workspace.Context.Packet.Report
                switch result {
                case .available(let record):
                    report = .init(record: record, diagnostics: [], maxBytes: maxBytes)
                case .unavailable(let reason), .malformed(let reason), .unmeasured(let reason):
                    report = .init(record: nil, diagnostics: [reason], maxBytes: maxBytes)
                }
                let format: Workspace.Context.Packet.Output
                switch output {
                case .some(.json): format = .json
                case .some(.human), nil: format = .human
                }
                print(report.render(format), terminator: "")
                Process.Exit.normal(report.status)
            case nil:
                throw .configuration("context operation was not provided")
            default:
                throw .configuration("context operation must be install, check, or packet")
            }
            return
        }

        let configuration = try Workspace.Configuration.load(at: root.checkout)
        switch operation {
        case .install:
            return
        case .sync:
            let selection = try Workspace.Selection.effective(at: root.checkout, in: configuration)
            try Workspace.Sync(root: root, selection: selection).run(dry: dry)
        case .build:
            let selection = try Workspace.Selection.effective(at: root.checkout, in: configuration)
            print(selection.origin)
            let status = try Workspace.Xcode.Build(root: root, selection: selection)
                .run(fresh: fresh, arguments: arguments)
            Process.Exit.normal(status)
        case .doctor:
            let selection = try Workspace.Selection.effective(at: root.checkout, in: configuration)
            let registry = try Workspace.Peer.Registry.load(at: root.checkout)
            let report = await Workspace.Doctor(
                root: root,
                configuration: configuration,
                selection: selection,
                peers: registry.peers,
                progress: .standardOutput
            ).run(access: institute ? .institute() : .contributor)
            print(report)
            Process.Exit.normal(report.status)
        case .coherence:
            let selection = try Workspace.Selection.effective(at: root.checkout, in: configuration)
            print(selection.origin)
            let receipt = await Workspace.Coherence.Run(
                root: root,
                configuration: configuration,
                selection: selection,
                buildPath: buildPath ?? .xcodebuildMerged
            ).run()
            print(receipt.canonical)
            let digest = try? receipt.digest(at: root)
            print(
                "coherence: verdict \(receipt.verdict.rawValue)"
                    + (digest.map { ", digest \($0)" } ?? " (digest unavailable)")
            )
            Process.Exit.normal(receipt.verdict.status)
        case .conversion:
            switch modes.first {
            case .some(.seal):
                let selection = try Workspace.Selection.effective(at: root.checkout, in: configuration)
                let receipt = try await Workspace.Conversion.Seal(root: root, selection: selection).run()
                print(receipt.canonical)
                let digest = try? receipt.digest(at: root)
                let summaryLine =
                    "conversion seal: \(receipt.cohort.count) repositories, "
                    + "\(receipt.pages.count) pages"
                    + (digest.map { ", digest \($0)" } ?? ", digest unavailable") + "\n"
                unsafe fputs(summaryLine, stderr)
            case .some(.check):
                let validated: File.Path
                do throws(File.Path.Error) {
                    validated = try File.Path(receiptPath)
                } catch {
                    throw .configuration("invalid --receipt path \(receiptPath): \(error)")
                }
                let bytes: [Byte]
                do throws(Either<File.System.Read.Full.Error, Never>) {
                    bytes = try File.System.Read.Full.read(from: validated) { (span: Swift.Span<Byte>) in
                        var storage = [Byte]()
                        storage.reserveCapacity(span.count)
                        for index in span.indices {
                            storage.append(span[index])
                        }
                        return storage
                    }
                } catch {
                    throw .configuration("cannot read --receipt \(receiptPath): \(error)")
                }
                let receipt: Workspace.Conversion.Receipt
                do throws(JSON.Error) {
                    receipt = try .init(jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self))
                } catch {
                    throw .configuration("cannot decode --receipt \(receiptPath): \(error)")
                }
                let diagnostics = Workspace.Conversion.Check.diagnostics(for: receipt, root: root)
                guard diagnostics.isEmpty else {
                    throw .configuration(diagnostics.joined(separator: "\n"))
                }
                print("conversion: current — \(receipt.cohort.count) repositories consistent")
            default:
                throw .configuration("conversion operation must be seal or check")
            }
        case .inventory:
            switch modes.first {
            case nil:
                print(
                    Workspace.Inventory.Register(
                        repositories: configuration.repositories
                    )
                )
                let registry = try Workspace.Peer.Registry.load(at: root.checkout)
                for peer in registry.peers {
                    let presence: Workspace.Peer.Presence
                    do throws(Workspace.Error) {
                        presence = .resolve(peer, at: try root.peer(peer))
                    } catch {
                        presence = .invalid("\(error)")
                    }
                    print(Workspace.Peer.Report(peer: peer, presence: presence))
                }
            case .some(.regenerate):
                let document = try Workspace.Configuration.Document.load(at: root.checkout)
                let http = GitHub.HTTP.Client<
                    Workspace.Inventory.Transport.Error,
                    GitHub.HTTP.Pagination.Error
                >(
                    agent: .init(rawValue: "swift-institute-workspace"),
                    version: .init(rawValue: "2022-11-28"),
                    execute: Workspace.Inventory.Transport.githubCLI()
                )
                let application = Workspace.Inventory.Application(
                    root: root.checkout,
                    policy: .institute(),
                    // `gh` supplies the credential; see Workspace.Inventory.Transport.
                    client: Workspace.Inventory.client(
                        http,
                        authentication: .token(.init(rawValue: ""))
                    )
                )
                let plan: Workspace.Inventory.Writer.Plan
                do {
                    plan = try await application.run(existing: document, dry: dry)
                } catch {
                    throw .configuration("inventory regenerate: \(error)")
                }
                switch plan {
                case .current:
                    print("inventory regenerate: Workspace.json is current")
                case .replace:
                    print(
                        dry
                            ? "inventory regenerate: would replace Workspace.json"
                            : "inventory regenerate: replaced Workspace.json"
                    )
                }
            case .some(.effective):
                guard let scope = Workspace.Inventory.Effective.Output.Scope(rawValue: inventoryScope)
                else {
                    throw .configuration(
                        "inventory effective: --inventory-scope must be public or effective"
                    )
                }
                guard !inventoryOutput.isEmpty else {
                    throw .configuration("inventory effective: --inventory-output is required")
                }
                let outputPath: File.Path
                do throws(File.Path.Error) {
                    outputPath = try File.Path(inventoryOutput)
                } catch {
                    throw .configuration(
                        "inventory effective: --inventory-output is not a valid path: \(error)"
                    )
                }

                let discovery: Workspace.Inventory.Private.Discovery
                switch scope {
                case .public:
                    // No private pass was requested; the report records the
                    // limb as not-requested rather than as an empty
                    // measurement.
                    discovery = .init(repositories: [], exclusions: [], unmeasured: [])
                case .effective:
                    let http = GitHub.HTTP.Client<
                        Workspace.Inventory.Transport.Error,
                        GitHub.HTTP.Pagination.Error
                    >(
                        agent: .init(rawValue: "swift-institute-workspace"),
                        version: .init(rawValue: "2022-11-28"),
                        execute: Workspace.Inventory.Transport.githubCLI()
                    )
                    let client = Workspace.Inventory.client(
                        http,
                        // `gh` supplies the credential; see Workspace.Inventory.Transport.
                        authentication: .token(.init(rawValue: ""))
                    )
                    do {
                        discovery = try await client.discoverPrivate(.institute())
                    } catch {
                        throw .configuration("inventory effective: \(error)")
                    }
                }

                let effective: Workspace.Inventory.Effective
                do throws(Workspace.Inventory.Effective.Error) {
                    effective = try .init(public: configuration, private: discovery)
                } catch {
                    throw .configuration("inventory effective: \(error)")
                }
                let report = try Workspace.Inventory.Effective.Output(
                    scope: scope,
                    effective: effective,
                    unmeasured: discovery.unmeasured,
                    root: root
                )
                try report.write(to: outputPath)
                let summary =
                    "inventory effective: scope \(scope.rawValue), "
                    + "\(report.combined.population.count) combined, "
                    + "\(report.unmeasured.count) unmeasured, wrote \(outputPath)\n"
                unsafe fputs(summary, stderr)
                Process.Exit.normal(report.exitCode)
            case .some(.pages):
                let selection = try Workspace.Selection.effective(at: root.checkout, in: configuration)
                let inventory = await Workspace.Pages.enumerate(root: root, selection: selection)
                print(inventory.canonical)
                let digest = try? inventory.digest(at: root)
                let counts = inventory.nonCanonicalCounts
                let countsDescription =
                    counts.isEmpty
                    ? "0 non-canonical"
                    : counts.sorted { $0.key < $1.key }.map { "\($1) \($0)" }.joined(separator: ", ")
                        + " non-canonical"
                let summaryLine =
                    "inventory pages: \(inventory.repositories.count) repositories, "
                    + "\(countsDescription)"
                    + (digest.map { ", digest \($0)" } ?? ", digest unavailable") + "\n"
                unsafe fputs(summaryLine, stderr)
                Process.Exit.normal(inventory.isFullyCanonical ? 0 : 1)
            default:
                throw .configuration(
                    "inventory operation must be regenerate, pages, effective, or absent"
                )
            }
        case .dependencies:
            let git = Git.Client()
            let head: Git.Object.ID
            let dirty: Swift.Bool
            do throws(Git.Client.Error) {
                head = try git.head(at: root.checkout.description)
                dirty = try git.status(at: root.checkout.description).contains {
                    $0.path == [UInt8]("Workspace.json".utf8)
                }
            } catch {
                throw .process("cannot identify the Workspace.json source revision: \(error)")
            }
            guard !dirty else {
                throw .configuration(
                    "Workspace.json has working-tree changes; an exact source revision "
                        + "cannot be recorded"
                )
            }
            let exceptions = Set(
                sanctionedExceptions.compactMap(Workspace.Repository.Key.init(identity:))
            )
            let report = await Workspace.Dependency.Audit(
                repositories: configuration.repositories,
                policy: .institute(),
                client: Workspace.Dependency.Remote.client(),
                sanctioned: exceptions,
                inventoryReference: "HEAD",
                inventoryRevision: head.rawValue
            ).run()
            switch output ?? .human {
            case .human: print(report)
            case .json: print(report.json, terminator: "")
            }
            Process.Exit.normal(report.status)
        case .compose:
            try Workspace.Composition(root: root, configuration: configuration)
                .compose(consumer: consumer, dependency: dependency)
        case .restore:
            try Workspace.Composition(root: root, configuration: configuration)
                .restore(consumer: consumer, dependency: dependency)
        case .verify:
            try Workspace.Composition(root: root, configuration: configuration)
                .verify(consumer: consumer, dependency: dependency)
        case .context:
            return
        case .navigation:
            return
        case .package:
            return
        case .lint:
            return
        case .github:
            return
        case .verification:
            // Unreachable: `.verification` returns above, before `root`/
            // `configuration` are even resolved, exactly like `.package`.
            // Still a required arm — `Operation` gained a case, and every
            // exhaustive switch over it must account for that, whether or
            // not this arm can run.
            return
        }
    }
}
