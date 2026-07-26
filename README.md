# Swift Institute Workspace

The front door to the Swift Institute: the public package inventory ([Workspace.json](Workspace.json)),
machine-checked facts about a checkout (`workspace doctor`), an isolated local development
checkout for Xcode (`workspace sync`), and local-source composition for cross-package work
(`workspace compose` / `restore` / `verify`).

| Command | What it does |
| --- | --- |
| `sync` | Clone missing repositories and fast-forward eligible ones. Never rewrites work. |
| `doctor` | Report what is measurably true about this checkout. |
| `compose` | Point one package's dependency at your local checkout of it, so edits are picked up. |
| `restore` | Undo a composition, returning the manifest to its declared form byte-for-byte. |
| `verify` | Report which source a dependency actually compiled from, read from resolved state. |

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

**The third command is slow the first time, and it is silent while it works.** Before it does
anything visible, `swift run` resolves and compiles the command-line application and its whole
dependency graph. Two costs stack up, and both are silent:

- **Resolution.** SwiftPM fetches the full transitive dependency graph — around **200
  repositories** — before compiling anything. On a first run with a cold package cache this is
  network-bound, so how long it takes depends on your connection more than your machine.
- **Compilation.** Roughly **5,900 build steps, about 4,200 of them compilations**. Measured
  with sources already local, that alone took **4–7 minutes** depending on the machine and its
  load; treat it as a floor, with fetching on top.

The earliest minutes print nothing at all while SwiftPM evaluates manifests, and the rest print
nothing either: no progress bar, no percentage, nothing until the build finishes and `sync`
prints its plan. Silence there is expected, not a hang.

If you would rather watch it work, run the build as its own step first — `swift build` prints
per-step progress, so the compile and the sync become two separate, legible steps:

```sh
swift build --package-path Application    # compiles; prints per-step [N/total] progress
swift run --package-path Application workspace sync
```

Later runs reuse the build and start in seconds.

`sync` prints its complete plan before changing repositories. It clones missing repositories
into the org hierarchy described above and only fast-forwards an existing repository when it
is clean, currently on `main`, tracks `origin/main`, and has no local commits. It never
resets, cleans, stashes, rebases, switches a feature branch, or overwrites a repository.

Preview the plan without changing files or Git metadata:

```sh
swift run --package-path Application workspace sync --dry-run
```

### Where packages materialize

The org hierarchy materializes **beside** your clone — the directory you cloned into plays
the organization role. For a clone at `X/Workspace`:

```text
X/
├── Workspace/              this repository: Application/, Workspace.json, institute.xcworkspace
├── swift-primitives/       ┐
├── swift-standards/        ├ materialization roots: independent repositories,
└── swift-foundations/      ┘ none part of this repository
```

Each package under those roots is an **independent repository** with its own history, remote,
CI, and license. Committing their contents to this repository is always wrong — work on a
package inside its own checkout and open the pull request on its own repository.

The roots sit beside the clone rather than inside it so the checkout stays a plain repository
and the hierarchy reads as the organization itself; `sync` writes only these roots beside the
directory you cloned, and never anywhere else. Materialized paths are regenerable state — if a
repository moves between organizations, its inventory entry changes and `sync` materializes
the new location, so nothing durable should reference one of these paths as though it were
stable.

> **Implementation status.** The tools currently resolve the materialization roots at the
> checkout root, so `sync` today still materializes the hierarchy inside your clone (those
> directories are gitignored there). Resolving the roots at the checkout's parent is being
> landed; this section documents the target layout.

## Reading `doctor`

`doctor` reports what is measurably true about your checkout right now — never a written
snapshot:

```sh
swift run --package-path Application workspace doctor
```

A healthy contributor run looks like this:

```text
toolchain: ok (population 4)
workspace-reference: ok (population 1)
materialization: ok (population 5)
working-state: ok (population 5)
resolved-pins: ok (population 0)
manifest-identity: ok (population 5)
inventory-currency: not run (institute-internal)
7 checks: 6 ok, 1 not run (institute-internal); measured populations: toolchain 4,
workspace-reference 1, materialization 5, working-state 5, resolved-pins 0,
manifest-identity 5
doctor: passed — 6 check(s) measured, 1 not run (institute-internal), 0 warning(s).
```

### The four results

Every check ends in exactly one of four states, and they are deliberately never printed the
same way:

| Result | Meaning |
| --- | --- |
| `ok (population n)` | The check ran over `n` subjects and found nothing wrong. |
| `warning findings` / `error findings` | The check ran and lists what it found. |
| `unmeasured — <reason>` | The check could **not** establish what it needed to measure. This is not a pass. |
| `not run (institute-internal)` | The check is out of scope for a contributor run. This is not a failure. |

Exit status follows: `0` when everything was measured and no errors were found (warnings still
exit `0`), `1` when a check measured an error, and **`2` if anything was `unmeasured`**. An
unmeasured check outranks an error precisely because it is worse: a failure to measure hides an
unknown number of both. A run containing one is never described as passing — "we could
not look" is a different answer from "we looked and it was fine", and conflating them is how a
broken check masquerades as a green one.

`inventory-currency` needs an authenticated GitHub client that the contributor path does not
carry, so it reports `not run`. **That is the expected result and it does not fail your
checkout.** If a step ever demands credentials or a repository you cannot read, that is a
defect worth reporting.

### Why a population is printed

The population is the check's evidence that it actually measured something. A check that
silently evaluated zero subjects would print exactly the same reassuring `ok` as one that
examined all of them, so the count is printed to make the difference visible: `materialization:
ok (population 5)` says five repositories were inspected, not that inspection was skipped.

`ok (population 0)` therefore means something specific: the check ran, its controls fired
correctly, and there were genuinely **zero subjects in existence** to measure. Above,
`resolved-pins: ok (population 0)` means no materialized repository has a `Package.resolved`
yet, so there are no pins to compare against their branch tips. An empty population measured
against a **non-empty** inventory is reported `unmeasured`, never `ok` — that case is a failure
to measure, and it is reported as one.

Each check also carries a known-positive and a known-negative control that run through the same
evaluation path as the real subjects. If the control that must fire does not, the check aborts
as `unmeasured` rather than reporting a green it did not earn.

### Severities

Dirty worktrees, untracked files, detached HEADs, feature branches, and stale resolved pins
are **warnings** — they may hold your unpushed work, so they are reported and left alone.
Identity, remote, upstream, divergence, toolchain, missing-package, and workspace-reference
problems are **errors**.

## Working across packages locally

Every package depends on its siblings by URL, so an edit to a dependency normally has to be
pushed before the package consuming it can see the change. That is the wrong loop for work that
spans two repositories at once.

`compose` closes it: it rewrites one `.package(url:)` clause in the consumer's manifest to a
`.package(path:)` clause pointing at the dependency's own checkout in this workspace, so builds
compile the source you are editing. `restore` puts the manifest back. `verify` reports which
source actually compiled, so you never have to trust your own memory of which state you left
things in.

Both packages must be named in [`Workspace.json`](Workspace.json) and checked out — run `sync`
first.

### The loop, end to end

Say you are changing `swift-color-standard` and want `swift-color` to compile against your
local copy.

**1. Compose.** Point the consumer at your local checkout:

```sh
swift run --package-path Application workspace compose \
  --consumer swift-color --dependency swift-color-standard
```

```text
Composed swift-color → swift-color-standard (local development source).
  manifest: <your-clone>/swift-foundations/swift-color/Package.swift
  now: .package(path: "<your-clone>/swift-standards/swift-color-standard")
  was: .package(url: "https://github.com/swift-standards/swift-color-standard.git", branch: "main")

  ⚠️  This manifest now carries a machine-local absolute path.
      Do NOT commit or push it — it resolves only on this machine.
```

The written path is deliberately **absolute**. That means the composed manifest is worthless on
any other machine — which is the point: if it escapes, it fails loudly at resolution instead of
quietly resolving to some other copy of the package. Treat a composed manifest as an
uncommittable local state.

**2. Edit and build.** Change `swift-color-standard` in its own checkout and build `swift-color`
normally. It now compiles your local source.

**3. Verify** — which source *actually* compiled:

```sh
swift run --package-path Application workspace verify \
  --consumer swift-color --dependency swift-color-standard
```

This reads SwiftPM's own resolved state; it never infers the answer from the manifest. It also
compares that against the composition ledger and warns if the two disagree — which means the
last resolve predates your current composition, and you need to re-resolve before believing
anything.

**4. Restore before you commit or push:**

```sh
swift run --package-path Application workspace restore \
  --consumer swift-color --dependency swift-color-standard
```

The declared `.package(url:)` clause comes back **byte-for-byte** — the original text is stored
when composing and replayed verbatim, not regenerated, so nothing about the manifest's
formatting drifts. Your work in the dependency's checkout, including unpushed commits, is never
touched: `restore` only edits the consumer's manifest.

### What `restore`'s structural check does and does not guarantee

`restore` finishes by evaluating the restored manifest in an isolated temporary directory, and
tells you so:

```text
  Structural check (resolve-free): the restored manifest evaluates, swift-color-standard
  is declared by URL again, and no local path leaked. This does NOT resolve
  dependencies and is NOT a remote-reproducibility guarantee.
```

Read that limit literally. The check **does** confirm three things: the restored manifest still
evaluates, the dependency is declared by URL again rather than by path, and no machine-local
path survived.

It **does not** resolve anything. It does not contact a remote, does not confirm the declared
URL exists, does not confirm the branch still has the commit you built against, and does not
prove your colleague or CI can build what you just restored. A green structural check means
*"the composition was removed cleanly"* — not *"this builds from its canonical sources."*

Confirming that last part is a step this tool deliberately leaves to you: run a full
resolve and build afterwards. If the dependency's local commits were never pushed, your
restored consumer will resolve to a remote that does not have them, and only a real resolve
will tell you.

### Limits

One composition per consumer/dependency pair at a time — compose again without restoring and it
refuses rather than stacking edits. If the composed clause has been hand-edited out of the
manifest, `restore` refuses to guess and says so. Both packages must be workspace repositories;
arbitrary local packages, multi-root setups, and Xcode-side composition are out of scope.

## Questions

Issues are the channel — for questions as much as for defects:

```bash
gh issue list --repo swift-institute/Workspace
```

There is no private support path and no internal-only documentation: this README is the whole
contributor surface. A step that does not work as described here, or that turns out to need
access you do not have, is a defect — please open an issue rather than working around it.

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
