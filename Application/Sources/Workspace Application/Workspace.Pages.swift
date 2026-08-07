extension Workspace {
    /// The inventory-driven, content-addressed authored-page enumeration
    /// (issue #82).
    ///
    /// Population comes solely from `Institute.json` and the resolved
    /// selection — never from a directory walk of the checkout root, so
    /// two machines that disagree about which repositories are
    /// materialized never disagree about what the roster names. The one
    /// rule that reads a checkout at all (``Kind/docc``) applies only to a
    /// repository whose materialization is `.canonical`; every other
    /// repository is recorded with its materialization state and no
    /// pages, never silently dropped.
    public enum Pages {}
}
