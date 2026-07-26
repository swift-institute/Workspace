# Swift Institute Workspace

The front door to the Swift Institute: the public package inventory ([Workspace.json](Workspace.json)),
machine-checked facts about a checkout (`workspace doctor`), and an isolated local development
checkout for Xcode (`workspace sync`).

## What Swift Institute is

Swift Institute builds a layered ecosystem of independent Swift packages. Three layers are
realised:

| Layer | Family | GitHub org |
| ---: | --- | --- |
| 1 | Primitives — atomic, dependency-light identity and value types | [swift-primitives](https://github.com/swift-primitives) |
| 2 | Standards — models of externally defined formats, protocols, and specifications | [swift-standards](https://github.com/swift-standards) |
| 3 | Foundations — operational capabilities composed from the lower layers | [swift-foundations](https://github.com/swift-foundations) |

Dependencies flow downward; same-layer edges are permitted only when they express a genuine
semantic prerequisite and the graph stays acyclic. Names above Layer 3 — components,
applications — are reservations recording intent. Never read such a name as evidence that the
thing exists.

Specification packages live in orgs named for the issuing authority:
[swift-ietf](https://github.com/swift-ietf) (the `swift-rfc-*` family),
[swift-iso](https://github.com/swift-iso), [swift-w3c](https://github.com/swift-w3c),
[swift-whatwg](https://github.com/swift-whatwg), and further authority, vendor, and
jurisdiction orgs on the same pattern. The `swift-*-standard` family inside swift-standards
models de-facto systems (Git, SwiftPM, GitHub, …) and is a different family from the
authority specification packages.

Every package is one repository; there is no monorepo. This repository clones selected
packages as independent sibling checkouts under `Packages/` and composes them into a single
Xcode workspace.

## Where facts come from

- **Inventory:** [Workspace.json](Workspace.json) is the public roster of packages this
  workspace manages, intended to grow to every public, non-archived Institute package.
- **Checkout facts:** `workspace doctor` measures the checkout directly — identities,
  remotes, branches, upstreams, toolchain, and workspace references.

Prefer running `doctor` over trusting any written snapshot: repository-state prose is a
measurement with a timestamp, and it drifts.

## Where open work lives

Open objectives are public GitHub issues on the relevant repositories:

```bash
gh issue list --repo swift-institute/Workspace
```

## Get started

**No Institute access is required.** Everything below works from a clone of this repository
alone, against public repositories, with no credentials and no internal tooling. If a step here
needs anything you cannot get, that is a defect — please open an issue.

Requires macOS 26, Xcode 26.6, Swift 6.3.3, and Git.

```sh
git clone https://github.com/swift-institute/Workspace.git
cd Workspace
swift run --package-path Application workspace sync
open institute.xcworkspace
```

`sync` prints its complete plan before changing repositories. It clones missing repositories
and only fast-forwards an existing repository when it is clean, currently on `main`, tracks
`origin/main`, and has no local commits. It never resets, cleans, stashes, rebases, switches
a feature branch, or overwrites a repository.

Preview the plan without changing files or Git metadata:

```sh
swift run --package-path Application workspace sync --dry-run
```

Check the checkout, canonical remotes, branches, upstreams, package identities, toolchain,
and relative workspace references:

```sh
swift run --package-path Application workspace doctor
```

Dirty worktrees and feature branches are reported as warnings and remain untouched.
Identity, remote, upstream, divergence, toolchain, missing-package, and workspace-reference
problems are errors.

## Contributing

Contributions come through the same path this README describes — there is no second, internal
one. Pick up an issue, work in the package's own repository under `Packages/`, and open a pull
request there; each package is an independent repository with its own history and CI.

Before opening a pull request, run `doctor` and make sure the package builds and tests from its
own repository. `doctor` reports which of its checks apply to your setup; checks that need
Institute access report that they did not run rather than failing your checkout.

## Scope

The current roster contains a three-repository proof chain spanning all three layers —
`swift-dimension-primitives → swift-color-standard → swift-color` — plus `swift-url-routing`
and `swift-http-body` for an active migration workspace. The Xcode workspace uses only
relative `Packages/<repository>` references; non-selected transitive dependencies still
resolve from their canonical remote URLs.

## License

Licensed under the terms in [LICENSE.md](LICENSE.md).
