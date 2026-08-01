#if canImport(Darwin)
private import Darwin
#elseif canImport(Glibc)
private import Glibc
#elseif canImport(Musl)
private import Musl
#endif

extension Workspace.GitHub {
    /// Wall-clock seconds since the POSIX epoch.
    ///
    /// A JWT's `iat` and `exp` are absolute instants agreed with a remote
    /// party, so a monotonic clock cannot serve here — `ContinuousClock`, the
    /// clock the rest of Workspace uses for measurement, has no relationship
    /// to GitHub's calendar at all.
    public enum Clock {}
}

extension Workspace.GitHub.Clock {
    public static func now() -> Swift.Int64 {
        Swift.Int64(unsafe time(nil))
    }
}
