# Swift Institute Workspace

The front door to the Swift Institute: the public package inventory
([Workspace.json](Workspace.json)), the default checkout
([Selection.json](Selection.json)) with a per-machine override that stays out of Git
(`Selection.local.json`), machine-checked facts about that checkout
(`workspace doctor`), an isolated local development checkout for Xcode (`workspace sync`),
and local-source composition for cross-package work (`workspace compose` / `restore` /
`verify`).

| Command | What it does |
| --- | --- |
| `sync` | Clone missing repositories and fast-forward eligible ones. Never rewrites work. |
| `doctor` | Report what is measurably true about this checkout. |
| `compose` | Point one package's dependency at your local checkout of it, so edits are picked up. |
| `restore` | Undo a composition, returning the manifest to its declared form byte-for-byte. |
| `verify` | Report which source a dependency actually compiled from, read from resolved state. |
| `context install\|check` | Install or verify the checkout-root agent entry point and canonical skill projections. |
| `navigation install\|check` | Install or verify the pinned cclsp/SourceKit-LSP integration for this checkout. |
| `package <action>` | Run SwiftPM build, test, resolution, and administration through the Swift coordinator. |
| `package lint` | Lint one package with the same binary, rules, and exit policy CI gates on. |
| `lint` | Lint the whole ecosystem. `install\|check` manage the pinned linter and its parity with CI. |

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
composes them into a single Xcode workspace. `Selection.json` contains only canonical
`owner/repository` identities and decides which inventory entries participate in the default
checkout. Placement and ordering derive from `Workspace.json` alone: each selected entry's
`organization` and `layer` fields decide the path, and inventory order decides synchronization
and Xcode order. Tools never infer a location from a package's name or by scanning the tree,
and materialized paths are regenerable state — when a repository transfers between
organizations, both documents must be updated explicitly before `sync` can proceed.

## Where facts come from

- **Inventory:** [Workspace.json](Workspace.json) is the public roster of packages this
  workspace manages, intended to grow to every public, non-archived Institute package.
- **Default checkout:** [Selection.json](Selection.json) is a membership list of canonical
  `owner/repository` identities. It deliberately does not repeat package metadata, paths, or
  ordering. It is *committed policy*: it decides what a fresh clone opens, for everyone.
- **Your checkout:** `Selection.local.json` is your own delta over that policy — `add` and
  `remove` — and it is gitignored. It is how you change what your machine opens without
  editing a tracked file.
- **Checkout facts:** `workspace doctor` measures the checkout directly — identities,
  remotes, branches, upstreams, toolchain, and workspace references.

`sync` and `doctor` load these files and fail before repository work if the selection is
missing, malformed, duplicated, or names an entry absent from the inventory. Those checks
apply to the *selection in effect* — the committed document with your override applied — so a
local file cannot buy an exemption from them, and a present-but-malformed override fails the
command rather than falling back to committed policy. They never treat an invalid selection as
permission to operate on the complete inventory. `compose`, `restore`,
and `verify` resolve their explicitly named operands against the complete inventory instead;
an operand does not have to remain in the default selection once it is already checked out.

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

Requires macOS 26, **Xcode 26.6 or newer**, **Swift 6.3.3 or newer**, and Git. Those two
versions are *minimums*, declared once in `Workspace.json` and enforced by `doctor` as a floor:
a newer toolchain passes, so you are never asked to install a beta to match a maintainer. The
Institute is moving to Swift 6.4 and above, and the floor rises when that toolchain is
installable without a preview — it is not raised ahead of it, because a floor nobody can meet
turns every green tick red for a reason unrelated to the change under test.

`swiftly` is how the Institute installs and selects Swift toolchains; install it if you do not
already keep one. If you keep more than one Swift toolchain installed,
[TOOLCHAINS.md](TOOLCHAINS.md) covers how to select one explicitly and how to determine which
one actually produced a result — machine-local configuration, not committed state.

The optional navigation setup additionally requires Node 18 or newer and Bun.

**Clone into a directory named `swift-institute`.** The layout is load-bearing, not cosmetic:
the materialized organization roots are placed beside this checkout, and the canonical skill
roots are resolved from its grandparent. Cloning into a bare directory puts both somewhere
nothing looks.

```sh
mkdir -p Institute/swift-institute && cd Institute/swift-institute
git clone https://github.com/swift-institute/Workspace.git
git clone https://github.com/swift-institute/Skills.git
cd Workspace
swift run --package-path Application workspace sync
open institute.xcworkspace
```

`Institute` is yours to name; `swift-institute` is not. That leaves you with
`Institute/swift-institute/Workspace` alongside `Institute/swift-institute/Skills`, the
materialized roots as further siblings, and the generated agent entry point in `Institute/`.

**Choose that parent directory as a long-lived one.** It becomes the home of every Institute
repository you will work in, and the sole custodian of your machine-local `Selection.local.json`,
which exists in no remote by construction.

The committed `Selection.json` decides that first synchronization. It selects the whole
public roster, so a fresh clone materializes every package in `Workspace.json`. To open
fewer, `remove` them in `Selection.local.json` below.

**To add packages to your own checkout, do not edit `Selection.json`.** Write
`Selection.local.json` beside it — the file is gitignored, so it never appears in
`git status` and can never be committed by a `git add .`:

```json
{
  "version": 1,
  "add": ["swift-primitives/swift-affine-primitives"],
  "remove": []
}
```

Identities are the exact `owner/repository` spelling from `Workspace.json`; order has no
effect. `add` and `remove` are both required — write `[]` for the one you are not using.
Then re-run `sync`.

It is a *delta*, not a replacement list, so a package added to the committed policy later
still reaches your machine. It also fails closed rather than doing something approximate:
adding a package the committed selection already has, removing one it does not, naming the
same package in both lists, removing everything, or naming a package absent from
`Workspace.json` each stop the command and say which file is wrong. Delete the file to go
back to the default checkout.

`Selection.json` itself is committed policy — the public default checkout. Edit it
only when you intend to change what *everyone's* fresh clone opens, and expect that change
to be reviewed as policy.

Both `sync` and `doctor` lead with which selection is in effect, so a package that is not
where you expect it names its own cause:

```text
selection: Selection.json — 5 selected; Selection.local.json — 1 added, 1 removed; 5 in effect
  Selection.local.json withholds: swift-foundations/swift-http-body
```

`institute.xcworkspace` is **generated, not committed** — `sync` writes it from the
selection in effect, which is why the third command must run before the fourth. A fresh clone
has no workspace file until it does; `workspace doctor` reports it missing and names the
command that writes it. Change the selection and re-run `sync` rather than editing the
workspace in Xcode, because the next `sync` rewrites whatever you edited.

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

That first `swift run` is the unavoidable self-hosting bootstrap. Once it has
produced `Application/.build/debug/workspace`, run all later SwiftPM work
through the coordinator rather than invoking raw build, test, or
package-administration commands.

Install the shared agent entry point:

```sh
swift run --package-path Application workspace context install
```

This validates every canonical skill before projecting it into your account's
`~/.claude/skills`, writes the generated root `AGENTS.md` and `CLAUDE.md`, and
fails closed on any path it does not own. The projection is account-wide so the
skills load whichever root in the hierarchy a session starts from.

Skills come from canonical roots resolved beside this checkout, all optional
because the hierarchy is:

| Root | Public | Holds |
| --- | --- | --- |
| `swift-institute/Skills` | yes — clone it | the Institute's shared skills |
| `swift-institute/Internal/Skills` | no | internal-only skills |
| `swift-institute/Engagement/Skills` | no | engagement-only skills |
| `rule-institute/Skills` | no | Rule Institute skills |

`swift-institute/Skills` is the one every contributor can clone, and the
quickstart above clones it. The command reports how many skills it projected
and from which roots, and **fails rather than reporting success when it
resolves no root at all** — an install that projected nothing is not an
install, and used to print the same line as one that worked.

### Install code navigation

Workspace owns the reproducible integration boundary between
[cclsp](https://github.com/swift-institute/cclsp) and Xcode's SourceKit-LSP:

```sh
Application/.build/debug/workspace navigation install
Application/.build/debug/workspace navigation check
```

`install` clones the public `sourcekit-lsp-adapter` line at the exact revision
compiled into Workspace, installs dependencies from cclsp's frozen Bun
lockfile, builds its Node executable, and writes two generated files beneath
the physical organization hierarchy:

- `.workspace/navigation/cclsp.json` — one SourceKit-LSP server for the
  Workspace Application and each currently materialized `Workspace.json`
  repository;
- `.workspace/navigation/mcp-server.json` — the command, arguments, and
  environment an MCP client registers.

The command prints the descriptor path. Client applications own their own
registration format, so Workspace does not rewrite a user's global client
configuration. The descriptor is the canonical value to translate into that
format.

SourceKit-LSP is launched through the generated `workspace navigation serve`
invocation. That typed boundary removes `TOOLCHAINS`, resolves
`sourcekit-lsp` through `xcrun`, and refuses a binary outside the Xcode selected
by `xcode-select`. cclsp remains a distinct third-party TypeScript tool: it is
not a Swift package, is not listed in `Workspace.json`, and is never resolved
from a personal fork or a fixed machine path.

The current generated configuration is deliberately per-package. A single
deduplicated Institute-wide index requires a larger IndexStore merge and
stabilizing acceptance probe; that exact Full-Swift remainder is tracked in
[issue #25](https://github.com/swift-institute/Workspace/issues/25). Workspace
does not claim that per-package navigation is equivalent to cross-package
index coverage.

Any earlier ad hoc merged-index pipeline and any prebuilt index bundle are
retired, unsupported, and not prerequisites for navigation. A clean machine
installs from the public cclsp revision and generates its own configuration
through the Workspace commands above; it does not copy old index artifacts.

### Lint

Workspace runs the same swift-linter CI gates on: the same binaries from the
same rolling `ci-binaries` release, verified against that release's
`SHA256SUMS`, invoked as `swift-linter <package-root> --exit-policy strict`
with the prebuilt standard runner provisioned on the environment. Workspace
sets that environment variable itself; a developer's shell profile is never
written, which is what makes the setup identical for everyone.

```sh
Application/.build/debug/workspace lint install     # fetch, verify, record the build
Application/.build/debug/workspace lint check       # is it the build CI consumes?
Application/.build/debug/workspace lint             # the whole ecosystem
Application/.build/debug/workspace lint --changed   # only packages with local work
workspace package lint                              # one package, from inside it
```

`package lint` takes no arguments: standing anywhere inside a package it finds
the package root and the installed binaries by walking up, reads no inventory,
and enumerates no organization. The whole-ecosystem sweep enumerates from
`Workspace.json` and lints packages concurrently. Both modes go through one
implementation, so a package's verdict cannot depend on which one asked for it.

**Every package is linted, whether or not it carries a `Lint.swift`.** A package
with one is dispatched exactly as CI dispatches it. A package without one cannot
go through the dispatcher at all — with no consumer manifest to classify, the
dispatcher falls through to a zero-rules configuration and exits clean having
loaded nothing — so it is handed straight to the prebuilt standard runner with an
explicit bundle selection on `SWIFT_LINTER_BUNDLE` and the exit policy on
`SWIFT_LINTER_EXIT_POLICY`, which is the same terminal the dispatched executable
reads.

The default bundle is the one the package's own layer already uses:
`primitives` for the primitives layer, `standards` for the standards layer,
`institute` for everything above them. That is not a second standard — it is
byte-for-byte what the package's configured peers activate, so writing the
`Lint.swift` its layer's convention calls for changes nothing about the verdict.
Picking each layer's own bundle rather than one global choice is what stops a
primitives-layer package from being measured against a *weaker* set than its
peers, which would reward staying unconfigured. A package that sits under no
layer root has no peers to inherit from and is reported `UNMEASURED` rather than
linted against a guess.

This one path has no CI counterpart: CI's activation signal *is* the presence of
`Lint.swift`, so for these packages CI runs nothing. The default-bundle run is
Workspace's own measurement. Nothing here changes what the gating CI legs
require.

**A lint run cannot report clean without having measured something.** The
engine ships rule-pack-agnostic: without a reachable configuration zero rules
fire, and three invocations of the dispatcher exit zero having printed nothing at
all — a directory holding Swift source but no `Lint.swift`, a *file* path rather
than a package root, and an empty directory. Exit status attests that a process
ran, never that it was configured. Every run is adjudicated against the engine's
always-on summary line, and a missing summary, zero active rules, or zero files
linted reports `UNMEASURED` — never clean, per package inside the sweep as well
as on its own. A sweep that enumerates the inventory and materializes nothing
fails rather than reporting an empty ecosystem clean. Exit status follows
`doctor`: 0 measured and passing, 1 measured with error-severity findings, 2
something could not be measured.

A file path is resolved to its enclosing package, which is linted whole and
whose diagnostics are then narrowed to that file — passing a file to the engine
is one of the silent-zero invocations and is unreachable through this
capability.

`lint check` compares the installed build's composite digest against the one CI
consumes. Because `ci-binaries` is a rolling tag, that establishes *you are
running what CI would install right now*, not what CI ran on any past run. The
macOS asset publishes on a slower cadence than Linux, so a transient divergence
is expected rather than a defect. A lint run itself never contacts the network.

### Build and test packages

The bootstrapped executable owns SwiftPM concurrency, job count, and build
state:

```sh
Application/.build/debug/workspace package build --package-path Application
Application/.build/debug/workspace package test --package-path Application --fresh
Application/.build/debug/workspace package resolve --package-path Application
```

Builds are serialized through a machine-wide advisory lock and compile with
three jobs. `--fresh` is available for build and test evidence: it uses a
unique scratch directory beside the package and removes it before returning.
Additional SwiftPM arguments use repeated `--argument` options, for example
`--argument=--filter --argument=Unit`; coordinator-owned path, state, and job
options cannot be overridden. The coordinator never edits
`Package.resolved`.

`sync` prints its complete plan before changing repositories. It clones missing repositories
into the org hierarchy described above and only fast-forwards an existing repository when it
is clean, currently on `main`, tracks `origin/main`, and has no local commits. It never
resets, cleans, stashes, rebases, switches a feature branch, or overwrites a repository.

Preview the plan without changing files or Git metadata:

```sh
swift run --package-path Application workspace sync --dry-run
```

### Where packages materialize

The org hierarchy materializes **beside** the physical checkout. Workspace resolves the
checkout through symlinks first, then uses exactly its parent as the organization directory;
invoking the tool through a symlink does not redirect that hierarchy. For a clone at
`X/Workspace`:

```text
X/
├── Workspace/              this repository: Application/, Workspace.json, Selection.json,
│                            your ignored Selection.local.json if you have one, and the
│                            generated, untracked institute.xcworkspace
├── swift-primitives/       ┐
├── swift-standards/        ├ materialization roots: independent repositories,
└── swift-foundations/      ┘ none part of this repository
```

Each package under those roots is an **independent repository** with its own history, remote,
CI, and license. Committing their contents to this repository is always wrong — work on a
package inside its own checkout and open the pull request on its own repository.

The roots sit beside the clone rather than inside it so the checkout stays a plain repository
and the hierarchy reads as the organization itself. `sync` creates repositories only beneath
those inventory-derived roots. Clone and update validation may use collision-resistant
temporary siblings in the same organization directory, and the generated
`institute.xcworkspace` remains inside the Workspace checkout. Materialized paths are
regenerable state — if a repository moves between organizations, its inventory entry changes
and `sync` materializes the new location, so nothing durable should reference one of these
paths as though it were stable.

Before inspecting or writing a materialized path, Workspace rejects `.` and `..` traversal,
symbolic links and non-directories in existing path prefixes, and any prefix that resolves
outside the physical organization directory. These checks assume a stable local filesystem
namespace: they are repeated safety snapshots, not a descriptor-relative guarantee against
another process replacing a directory concurrently.

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

A maintainer with an authenticated `gh` can ask for it explicitly:

```sh
swift run --package-path Application workspace doctor --institute
```

That discovers the live Institute organizations — roughly one request per repository, about
460 today — and compares the result with `Workspace.json` in both directions, naming every
repository that is on one side and not the other. It is opt-in rather than automatic on
purpose: `doctor` is otherwise credential-free and offline, and it must not become a
different, slower, network-bound command on the machines that happen to have `gh` logged in.
Nothing about the contributor invocation above changes. Drift is caught without anyone
remembering the flag by the `roster-currency` workflow, which runs the same command nightly.

### Why a population is printed

The population is the check's evidence that it actually measured something. A check that
silently evaluated zero subjects would print exactly the same reassuring `ok` as one that
examined all of them, so the count is printed to make the difference visible: `materialization:
ok (population 5)` says five repositories were inspected, not that inspection was skipped.

`ok (population 0)` therefore means something specific: the check ran, its controls fired
correctly, and there were genuinely **zero subjects in existence** to measure. Above,
`resolved-pins: ok (population 0)` means no materialized repository has a `Package.resolved`
yet, so there are no pins to compare against their branch tips. For repository-subject checks,
an empty population measured against a **non-empty selection** is reported `unmeasured`, never
`ok` — that case is a failure to measure, and it is reported as one. The institute-only
`inventory-currency` check is the exception: it compares the complete inventory with live
discovery and reports their union as its measured population.

Each check also carries a known-positive and a known-negative control that run through the same
evaluation path as the real subjects. If the control that must fire does not, the check aborts
as `unmeasured` rather than reporting a green it did not earn.

### Materialization states

For each selected repository, `doctor` distinguishes the active sibling location from the
superseded location inside the Workspace checkout:

| On-disk state | Result |
| --- | --- |
| Git repository only at the sibling location | Canonical and `ok`. |
| Git repository only inside the Workspace checkout | Legacy and an error. |
| Git repositories at both locations | An error; the sibling is active and the legacy checkout is left untouched. |
| No Git repository at either location | Absent and an error. |
| A location cannot be formed or safely inspected | Invalid and an error. |

Workspace never migrates or deletes a legacy checkout. Only the active sibling repository
enters the downstream working-state, resolved-pin, and manifest-identity checks; a legacy-only
tree never satisfies them.

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

Both packages must be named in [`Workspace.json`](Workspace.json) and checked out. If one is
not already checked out because it is outside the committed default, add its canonical
identity to the `add` list in your `Selection.local.json`, then run `sync` before composing
it — not to [`Selection.json`](Selection.json), which is committed policy rather than your
own checkout.

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
  manifest: <checkout-parent>/swift-foundations/swift-color/Package.swift
  now: .package(path: "<checkout-parent>/swift-standards/swift-color-standard")
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
relative sibling-layout references (`../swift-foundations/swift-color`, …); non-selected
transitive dependencies still resolve from their canonical remote URLs.

## License

Licensed under the terms in [LICENSE.md](LICENSE.md).
