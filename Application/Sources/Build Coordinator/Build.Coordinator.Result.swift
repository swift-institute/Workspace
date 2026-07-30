extension Build.Coordinator {
    /// The outcome of one coordinated `xcodebuild` operation.
    ///
    /// `standardOutput`/`standardError` are populated only when the caller
    /// opted into `capturingDiagnostics` — every other coordinated run
    /// leaves them `nil` and streams live to the parent's own streams
    /// instead, per ``coordinated(_:in:describing:capture:cleanup:)``.
    public struct Result: Sendable, Equatable {
        public let exitCode: Swift.Int32
        public let standardOutput: [Swift.UInt8]?
        public let standardError: [Swift.UInt8]?

        public init(
            exitCode: Swift.Int32,
            standardOutput: [Swift.UInt8]? = nil,
            standardError: [Swift.UInt8]? = nil
        ) {
            self.exitCode = exitCode
            self.standardOutput = standardOutput
            self.standardError = standardError
        }
    }
}
