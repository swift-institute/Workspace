/// The architecture model's namespace root.
///
/// The `Workspace Application` module declares its own `Workspace` namespace;
/// this module is a leaf that the application composes, so it declares the
/// namespace independently rather than depending upward. Consumers that
/// import both modules qualify the architecture side as
/// `WorkspaceArchitectureModel.Workspace`.
public enum Workspace {}
