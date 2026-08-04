public import JSON

extension Workspace.Verification {
    /// The exact toolchain and host a verification run measured on.
    ///
    /// Every field is an *observed* fact — read from the invoking process's
    /// own tools and environment at run time — never a configured minimum
    /// or a caller's claim. ``runnerImage`` is `nil` off a hosted runner:
    /// the producer requirement is "record rather than invent hosted image
    /// identity" (Task 2-01), so a local run must leave it absent rather
    /// than synthesize a value no image actually reported.
    public struct Environment: Equatable, Sendable, JSON.Serializable {
        public let swift: Swift.String
        public let xcode: Swift.String
        public let sdk: Swift.String
        public let os: Swift.String
        public let architecture: Swift.String
        public let runnerImage: Swift.String?

        public init(
            swift: Swift.String,
            xcode: Swift.String,
            sdk: Swift.String,
            os: Swift.String,
            architecture: Swift.String,
            runnerImage: Swift.String?
        ) {
            self.swift = swift
            self.xcode = xcode
            self.sdk = sdk
            self.os = os
            self.architecture = architecture
            self.runnerImage = runnerImage
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "swift": value.swift.json,
                "xcode": value.xcode.json,
                "sdk": value.sdk.json,
                "os": value.os.json,
                "architecture": value.architecture.json,
                "runnerImage": value.runnerImage.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let swift = object["swift"] else { throw .missingKey("swift") }
            guard let xcode = object["xcode"] else { throw .missingKey("xcode") }
            guard let sdk = object["sdk"] else { throw .missingKey("sdk") }
            guard let os = object["os"] else { throw .missingKey("os") }
            guard let architecture = object["architecture"] else { throw .missingKey("architecture") }
            return try Self(
                swift: Swift.String(json: swift),
                xcode: Swift.String(json: xcode),
                sdk: Swift.String(json: sdk),
                os: Swift.String(json: os),
                architecture: Swift.String(json: architecture),
                runnerImage: Swift.String?(json: object["runnerImage"] ?? .null)
            )
        }
    }
}

extension Workspace.Verification.Environment {
    /// The current platform, exactly ``Workspace/Coherence/Run``'s own
    /// derivation — duplicated rather than shared across modules of the
    /// same package for a three-line `#if os(...)` switch would be a
    /// heavier coupling than the value it names.
    static var currentOS: Swift.String {
        #if os(macOS)
            "macos"
        #elseif os(Linux)
            "linux"
        #elseif os(Windows)
            "windows"
        #else
            "unknown"
        #endif
    }

    /// The compiled architecture — never the *host's* architecture under
    /// Rosetta or a cross-compiled toolchain, which is exactly the
    /// distinction a verification receipt must record faithfully.
    static var currentArchitecture: Swift.String {
        #if arch(arm64)
            "arm64"
        #elseif arch(x86_64)
            "x86_64"
        #else
            "unknown"
        #endif
    }

    /// `RUNNER_NAME`/`ImageOS` are GitHub Actions' own hosted-runner
    /// variables — real values a hosted image sets, never a name this
    /// instrument constructs. Absent both, this run is not on a hosted
    /// runner and ``Environment/runnerImage`` records that honestly as
    /// `nil` rather than falling back to a guess.
    static func currentRunnerImage() -> Swift.String? {
        if let image = Workspace.Doctor.variable("ImageOS"), !image.isEmpty {
            return image
        }
        if let name = Workspace.Doctor.variable("RUNNER_NAME"), !name.isEmpty {
            return name
        }
        return nil
    }

    /// Reads `swift --version`, `xcodebuild -version`, and `xcrun --sdk
    /// macosx --show-sdk-version` the same way
    /// ``Workspace/Doctor/toolchain()`` does — first line of real spawned
    /// output, `"unknown"` only when the interrogation itself failed. This
    /// metadata is descriptive, never gating: a verification run must not
    /// fail because it could not identify its own toolchain string.
    static func observe() -> Workspace.Verification.Environment {
        .init(
            swift: Self.line(try? Workspace.Doctor.spawn("swift", arguments: ["--version"])),
            xcode: Self.line(try? Workspace.Doctor.spawn("xcodebuild", arguments: ["-version"])),
            sdk: Self.line(
                try? Workspace.Doctor.spawn(
                    "xcrun",
                    arguments: ["--sdk", "macosx", "--show-sdk-version"]
                )
            ),
            os: Self.currentOS,
            architecture: Self.currentArchitecture,
            runnerImage: Self.currentRunnerImage()
        )
    }

    private static func line(_ value: Swift.String?) -> Swift.String {
        guard let value else { return "unknown" }
        return value.split(separator: "\n").first.map(Swift.String.init) ?? "unknown"
    }
}
