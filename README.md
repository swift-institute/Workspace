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
packages as independent checkouts materialized in the org hierarchy — one root per layer
organization (`swift-primitives/`, `swift-standards/`, `swift-foundations/`), with packages
owned by a specification-authority, vendor, or jurisdiction organization nested one level
deeper under their layer root (for example `swift-standards/swift-ietf/<package>`) — and
composes them into a single Xcode workspace. Placement derives from `Workspace.json` alone:
each entry's `organization` and `layer` fields decide the path. Tools never infer a location
from a package's name or by scanning the tree, and materialized paths are regenerable state —
when a repository transfers between organizations, re-running `sync` materializes its new
location.

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

The first `swift run` builds the application before it does anything visible: roughly four
thousand compile steps, several minutes, and the earliest of those minutes print nothing at
all while SwiftPM evaluates manifests. Silence there is expected, not a hang.

`sync` prints its complete plan before changing repositories. It clones missing repositories
into the org hierarchy described above and only fast-forwards an existing repository when it
is clean, currently on `main`, tracks `origin/main`, and has no local commits. It never
resets, cleans, stashes, rebases, switches a feature branch, or overwrites a repository.

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

### Editing across package boundaries

Every package depends on its siblings by URL, so an edit to a dependency normally has to be
pushed before the package consuming it can see the change. That is the wrong loop for work
that spans two repositories at once. `compose` closes it: it rewrites one `.package(url:)`
clause in the consumer's manifest to a `.package(path:)` clause pointing at the dependency's
own checkout in this workspace, so builds compile the source you are editing.

```sh
swift run --package-path Application workspace compose --consumer <name> --dependency <name>
swift run --package-path Application workspace verify  --consumer <name> --dependency <name>
swift run --package-path Application workspace restore --consumer <name> --dependency <name>
```

Both names are repositories in [Workspace.json](Workspace.json), already materialized by
`sync`. `compose` records the clause it replaced, so `restore` puts the original back
**byte for byte** — the manifest returns to exactly the bytes it had, not to a regenerated
equivalent — and drops the record. `restore` never touches the dependency's worktree, so an
unpushed local commit there survives the whole cycle.

A composed manifest holds an absolute path that is meaningful only on the machine that wrote
it. That is deliberate — off-machine it fails loudly at resolution rather than quietly
resolving to something else — but it means a composed manifest must never be committed or
pushed. `compose` prints that warning; run `restore` before you push.

`verify` answers a different question from either: it reports which source the compiler is
actually using, read from SwiftPM's own resolved state rather than inferred from the manifest,
and says so when that disagrees with what `compose` recorded.

What `restore` checks, and what it does not: it evaluates the restored manifest in isolation
and confirms it parses, declares the dependency by URL again, and leaked no local path. It
does **not** resolve dependencies, so it is not a guarantee that the dependency resolves from
its canonical remote. Run a full build afterwards to establish that.

### Migrating from the flat `Packages/` layout

Checkouts synced before the org layout hold packages flat under `Packages/`. That layout is
superseded. Re-run `workspace sync`: it materializes the org hierarchy as fresh clones and
leaves `Packages/` untouched. `workspace doctor` reports each remaining flat checkout
(`layout-migration`, a warning) so nothing is forgotten. Move any local work you want to
keep — unpushed branches or dirty worktrees — into the new checkout or push it, then remove
`Packages/` yourself: tooling never deletes it.

## Contributing

Contributions come through the same path this README describes — there is no second, internal
one. Pick up an issue, work in the package's own repository at its org-layout checkout, and
open a pull request there; each package is an independent repository with its own history and
CI.

Before opening a pull request, run `doctor` and make sure the package builds and tests from its
own repository. `doctor` reports which of its checks apply to your setup; checks that need
Institute access report that they did not run rather than failing your checkout.

## Scope

The current roster contains a three-repository proof chain spanning all three layers —
`swift-dimension-primitives → swift-color-standard → swift-color` — plus `swift-url-routing`
and `swift-http-body` for an active migration workspace. The Xcode workspace uses only
relative org-layout references (`swift-foundations/swift-color`, …); non-selected transitive
dependencies still resolve from their canonical remote URLs.

## License

Licensed under the terms in [LICENSE.md](LICENSE.md).
