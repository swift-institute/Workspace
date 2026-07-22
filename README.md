# Swift Institute Workspace

The Swift Institute Workspace creates an isolated local checkout of Institute packages for Xcode development. Every package remains a normal, independent Git repository with its canonical `origin`.

This first public proof contains one real three-layer chain:

```text
swift-dimension-primitives → swift-color-standard → swift-color
```

## Requirements

- macOS 26
- Xcode 26.6
- Swift 6.3.3
- Git

## Get started

```sh
git clone https://github.com/swift-institute/Workspace.git
cd Workspace
swift run workspace sync
open institute.xcworkspace
```

`sync` prints its complete plan before changing repositories. It clones missing repositories and only fast-forwards an existing repository when it is clean, currently on `main`, tracks `origin/main`, and has no local commits. It never resets, cleans, stashes, rebases, switches a feature branch, or overwrites a repository.

Preview the plan without changing files or Git metadata:

```sh
swift run workspace sync --dry-run
```

Check the checkout, canonical remotes, branches, upstreams, package identities, toolchain, and relative workspace references:

```sh
swift run workspace doctor
```

Dirty worktrees and feature branches are reported as warnings and remain untouched. Identity, remote, upstream, divergence, toolchain, missing-package, and workspace-reference problems are errors.

## Scope

`Workspace.json` is the public source of truth. Its schema is intended to grow to every public,
non-archived Swift Institute package. The initial roster contains the three-repository proof
chain plus `swift-url-routing`, which is included as the first active migration workspace.

The Xcode workspace uses only relative `Packages/<repository>` references. Non-selected transitive dependencies still resolve from their canonical remote URLs during this bounded proof.
