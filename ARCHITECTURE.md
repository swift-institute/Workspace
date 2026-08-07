# Workspace Architecture

## Mission

Workspace is the Swift Institute front door. It serves three roles:

- **Inventory** — `Institute.json` is the public roster of Institute package repositories,
  intended to grow to every public, non-archived package.
- **Fact oracle** — `institute doctor` reports what is true right now about the checkout:
  identities, remotes, branches, upstreams, toolchain, and workspace references. Facts come
  from executed checks, not from prose snapshots; a check that cannot distinguish "measured
  clean" from "failed to measure" does not ship.
- **Development checkout** — `institute sync` materializes eligible repositories as normal,
  independent Git clones and composes them into a deterministic Xcode workspace.

### The contributor path is a first-class surface

Someone with no Institute access clones this repository alone and gets to a working, understood
setup from its README. That path is a product surface, not a by-product of the internal one, and
it constrains the design:

- **Nothing on the contributor path may depend on a private repository.** `sync` and `doctor`
  run under plain `swift run`; no step may require internal tooling, credentials, or a
  repository the contributor cannot read.
- **A check that cannot run without Institute access is scoped, not silently skipped.** Such a
  check declares itself institute-internal and reports that it did not run. "Did not run,
  by scope" and "ran and found nothing" are different results and are never printed the same
  way.
- A contributor run that reaches a correct, complete conclusion exits successfully. Absence of
  private access is not a defect in the checkout and is never reported as one.

### Composition boundary

Policy, planning, inspection, and reporting live in the `Workspace Application` library target.
The `workspace` executable is thin composition over it and owns nothing else. Any future
front-end composes the same library rather than reimplementing its policy — the split exists so
that the choice of front-end stays open.

Architecturally, Workspace is process/application tooling outside the three realised package
layers. It discovers eligible public Swift Institute repositories, plans safe synchronization,
reports policy violations, and composes the Institute packages that own Git, SwiftPM, Xcode,
JSON, XML, filesystem, process, and GitHub behavior.

Workspace owns application policy only:

- public and non-archived repository eligibility;
- synchronization safety and dry-run guarantees;
- doctor severity policy;
- deterministic inventory and workspace orchestration;
- command-line composition.

It does not own representations or operational clients for external systems.

The widened charter changes what Workspace reports, not how it is built. The immediate
engineering increment is unchanged: the local-resolution milestone — generated
`.package(path:)` composition, the sentinel proof, and clean restoration — per
`Research/Local Resolution/Workspace Finalization Handoff.md`. The decisions recorded in that
handoff's "Accepted architecture" section are settled and are not reopened by this mission
statement. Doctor growth (new checks) layers onto the same owner packages and the same
severity policy; it does not create new packages or new lower-layer ownership.

## Application layout

`Application/` is the Swift package for the command-line product. The repository root contains
the shared inventory and generated workspace so future end-user applications can be added as
sibling directories without turning the command-line package into the repository root.

```text
X/                              the directory playing the organization role
├── Workspace/                  this repository, cloned into X
│   ├── Application/            process/application Swift package
│   │   ├── Sources/
│   │   │   ├── Workspace Application/
│   │   │   └── Workspace CLI/
│   │   └── Tests/
│   ├── Institute.json          application-owned inventory policy
│   └── institute.xcworkspace/  deterministic generated workspace
├── swift-primitives/           materialized org root (layer 1)
├── swift-standards/            materialized org root (layer 2)
│   └── swift-ietf/             authority orgs nest under their layer root
└── swift-foundations/          materialized org root (layer 3)
```

Names such as `macOS Application/` and `iOS Application/` are reserved for concrete future
products. A generic `Application/` container is not introduced until more than one graphical
application establishes a coherent shared hierarchy.

## Materialization layout

`sync` materializes the org hierarchy — the one layout for every checkout, contributors
included.

**Where the roots live.** The active materialization roots are **siblings of the physical
checkout**. `Workspace.Root` resolves the checkout through symlinks and derives exactly one
hierarchy root: its parent. For a checkout physically located at `X/Workspace`, `sync`
populates `X/swift-primitives/`, `X/swift-standards/`, `X/swift-foundations/` (and the
reserved `X/swift-components/`, `X/swift-applications/`): `X` plays the organization role,
and the checkout stays a plain repository beside its org roots. No initializer accepts
checkout and hierarchy independently because that parent-child relation is the invariant.

Repositories are written only beneath inventory-derived roots in the hierarchy. Clone and
update validation may create collision-resistant temporary siblings in that same hierarchy;
the generated `institute.xcworkspace` and composition ledger remain checkout-owned state.
This active layout supersedes the earlier inside-the-checkout materialization. The
repository's `.gitignore` keeps the old root entries transitionally so a checkout created
under that earlier layout does not surface those trees as untracked noise.

**Materialization safety boundary.** Before a materialized path is inspected or mutated,
Workspace rejects `.` and `..` traversal components. Every existing target prefix below the
physical hierarchy is inspected without following symbolic links, must be a directory, and
must canonically resolve within that hierarchy. The preflight is repeated across creation,
staging, move, and update boundaries. It is nevertheless a snapshot of a mutable namespace,
not a descriptor-relative object capability: protection against a concurrent hostile
rename or replacement belongs in filesystem operations that hold and traverse directory
descriptors. Workspace's guarantee assumes a stable local namespace.

**Legacy state.** Doctor classifies each selected repository as canonical (sibling only),
legacy (inside the checkout only), both, absent, or invalid. Legacy, both, absent, and invalid
are errors; when both exist, the sibling is active. Workspace never migrates or deletes the
legacy checkout, and only an active sibling repository participates in downstream census,
pin, and manifest checks.

**Where a package materializes.** Its location is a pure function of its `Institute.json`
entry: the layer's root organization, then — when the owning organization is not the layer
root — the organization, then the repository name. `swift-primitives/swift-dimension-primitives`;
`swift-standards/swift-ietf/swift-rfc-9110`. Two properties are requirements (issue #17):

1. **The inventory is the sole name → org → path authority.** Every tool resolves locations
   through `Workspace.Layout` over inventory fields (`organization`, `layer`, `name`); no
   tool walks the tree or infers a path from a name pattern. Packages sit at varying depths,
   and a walker with its own layout assumptions fails toward clean-looking empties.
2. **Materialized paths are regenerable state.** A repository that transfers between
   organizations changes its inventory entry, and `sync` materializes the new location.
   Generated composition references and workspace files are re-derived, never hand-maintained,
   and nothing durable may reference a materialized path as stable.

## Package missions and layers

| Package | Layer or role | Mission |
| --- | ---: | --- |
| `swift-package-primitives` | 1 | Provide atomic package, product, and target identity types. |
| `swift-spm-standard` | 2 | Model externally defined SwiftPM manifest and dependency representations. |
| `swift-git-standard` | 2 | Model specified Git object IDs, refs, advertisements, status records, and implemented repository formats. |
| `swift-xcode-standard` | 2 provisional | Model researched Xcode workspace and scheme serialization terms without claiming an Apple-published complete specification. |
| `swift-github-standard` | 2 planned | Model GitHub wire representations after deliberate migration from `swift-github-types`. |
| `swift-file-system` | 3 | Own typed filesystem inspection, atomic writes, moves, deletion, and temporary-path operations. |
| `swift-arguments` | 3 | Own schema-driven command parsing, help, diagnostics, and process-runner composition. |
| `swift-environment` | 3 | Own Foundation-free access to the invoking process environment. |
| `swift-process` | 3 | Own Foundation-free process spawning, capture, termination, and current-process exit. |
| `swift-json` | 3 | Own JSON parsing, serialization, and format-specific value conversion. |
| `swift-xml` | 3 | Own XML document composition and serialization used by Xcode operations. |
| `swift-git` | 3 | Execute Git operations and translate command output into `swift-git-standard` representations. |
| `swift-xcode` | 3 | Generate and atomically write Xcode workspace and scheme artifacts using `swift-xml`. |
| `swift-package-manager` | 3 | Execute installed SwiftPM operations and return `swift-spm-standard` values. |
| `swift-package-graph` | 3 | Compose manifest values into package dependency graphs. |
| `swift-github` | 3 planned | Own authenticated GitHub operations and pagination over `swift-github-standard` values. |
| `Workspace/Application` | process/tooling | Apply Institute eligibility, sync-safety, diagnostic, and inventory policy through the three realised package layers. |

## Products and targets

| Package | Product | Target | Public surface |
| --- | --- | --- | --- |
| `swift-git-standard` | `Git Standard` | `Git Standard` | `Git.Object`, `Git.Ref`, `Git.Status` |
| `swift-git` | `Git` | `Git Foundation` | `Git.Client` |
| `swift-xcode-standard` | `Xcode Workspace Standard` | same | `Xcode.Workspace` representations |
| `swift-xcode-standard` | `Xcode Scheme Standard` | same | `Xcode.Scheme` representations |
| `swift-xcode` | `Xcode Workspace` | same | workspace XML and atomic write operations |
| `swift-xcode` | `Xcode Scheme` | same | scheme XML and atomic write operations |
| `swift-package-manager` | `Package Manager` | same | `Package.Manager` installed-toolchain operations |
| `Workspace/Application` | `Workspace Application` | same | application policy and orchestration |
| `Workspace/Application` | `workspace` | `Workspace CLI` | command-line composition only |

`Xcode.Project` and `Xcode.Workspace` remain separate SwiftPM modules and products. Project-file
support is research-gated and will not be published as a placeholder.

## Dependency legality

Dependencies flow downward by layer. Acyclic same-layer composition is permitted when the edge
expresses semantic composition and does not manufacture a helper package:

```text
Workspace/Application (process/tooling)
├── swift-arguments (L3)
├── swift-environment (L3)
├── swift-git (L3) ──────────────── swift-git-standard (L2)
│   └── swift-process (L3)
├── swift-xcode (L3) ────────────── swift-xcode-standard (L2 provisional)
│   ├── swift-xml (L3)
│   └── swift-file-system (L3)
├── swift-package-manager (L3) ──── swift-spm-standard (L2)
│   ├── swift-json (L3)
│   └── swift-process (L3)
├── swift-file-system (L3)
├── swift-json (L3)
├── swift-process (L3)
└── future swift-github (L3) ────── future swift-github-standard (L2)
```

The repaired SwiftPM cascade is
`swift-package-primitives (L1) → swift-spm-standard (L2) → swift-package-manager / swift-manifests / swift-package-graph (L3)`.
`swift-spm-standard` must not regain its former upward dependency on `swift-paths`.

## Heritage and decomposition decisions

- `swift-github-types` is not accepted as a Layer-2 foundation because it mixes wire values,
  client/router behavior, Layer-3 dependencies, and Foundation. Its representations will migrate
  deliberately into `swift-github-standard`; operational behavior will migrate into
  `swift-github`. No overlapping third GitHub family is introduced.
- `swift-plist` currently mixes externally defined property-list formats and Layer-3 composition.
  A future `swift-plist-standard` plus `swift-plist` split is warranted before OpenStep project
  serialization, but no package is created until Xcode.Project research fixes the semantic scope.
- `swift-git-process` is rejected. Process execution is an implementation mechanism of the single
  `swift-git` operational client, not an integration domain with multiple backends.
- `swift-workspace-standard` is rejected. `Institute.json`, sync rules, and doctor severity are
  Institute application policy, not external standards.
- W3C XML modules are not used directly for Xcode serialization. `swift-xcode` composes the
  Layer-3 `swift-xml` foundation.

## Semantic-type follow-up

The first operational slice intentionally establishes ownership before completing type refinement.
The following raw values require owner-level adjudication:

| Current value | Required direction | Owner |
| --- | --- | --- |
| Git working directory `String` | `File.Path` or `File.Directory` | `swift-git` |
| Git remote `String` | Git remote-location type supporting URI, path, and scp-like syntax | `swift-git-standard` |
| Git revision-range `String` | typed revision/range expression | `swift-git-standard` |
| Git status `[UInt8]` paths | `[Byte]` or a typed Git path representation | `swift-git-standard` |
| SwiftPM operation directory `String` | `File.Directory` | `swift-package-manager` |
| Workspace repository name `String` | validated `Workspace.Repository.Name` or reused coherent identity | Workspace policy |
| Workspace repository URL `String` | Git remote-location type | `swift-git-standard` |
| configured Swift/Xcode version `String` | existing version type where semantics match; otherwise a scoped type | owning standard/application |

Diagnostic prose remains `String`; replacing it would add no semantic information.

## Acceptance gates

### Git vertical slice

- parse official ref advertisements and porcelain status fixtures;
- prove dirty, feature-branch, wrong-remote, wrong-upstream, and ahead repositories are not
  rewritten;
- prove dry-run changes neither files nor Git metadata;
- clone into a collision-resistant same-filesystem sibling and install by atomic move;
- fast-forward only an eligible clean `main` checkout.

### Xcode.Workspace vertical slice

- construct a semantic `Xcode.Workspace` value;
- serialize through `swift-xml` with deterministic relative references;
- keep the institute bundle inside the checkout, with `group:Application` for the application
  and `group:../<inventory-derived-reference>` for every sibling repository;
- atomically write `contents.xcworkspacedata` through `swift-file-system`;
- emit no absolute local paths.

### SwiftPM vertical slice

- keep the Layer-1 → Layer-2 → Layer-3 cascade legal;
- evaluate `swift package dump-package` through `swift-package-manager`;
- use typed manifest identities in doctor and package-graph operations.

### GitHub inventory slice

- discover every public, non-archived package repository with pagination;
- exclude private, archived, non-package, and policy-ineligible repositories;
- expose the committed name → organization → relative-path register through a read-only
  `institute inventory`;
- put discovery and replacement only behind `institute inventory regenerate`, with a
  nonmutating `--dry-run` plan and a clean-worktree publication gate;
- produce a stable sort and byte-for-byte deterministic `Institute.json`;
- preserve application-owned annotations without duplicating GitHub client behavior.

### Application and release gate

- no Apple Foundation import in any main target;
- no local Shell, Git client, Xcode serializer, JSON decoder, manifest parser, or filesystem boundary;
- focused tests for policy plus owner-package tests for every added capability;
- clean-room resolution after newly created repositories are explicitly made public;
- `institute sync --dry-run`, `institute sync`, and `institute doctor` pass from a clean clone;
- CI, README, architecture documentation, and deterministic generated workspace agree;
- no tag or release until every preceding gate is green.
