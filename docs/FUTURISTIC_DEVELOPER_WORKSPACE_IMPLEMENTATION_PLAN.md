# DevDesk Futuristic Developer Workspace Implementation Plan

**Document status:** All 11 implementation phases completed; external publisher gates remain  
**Audit date:** 2026-07-22  
**Target platforms:** Android and Windows  
**Product posture:** local-first, offline-capable, explicit network access, user-owned files  
**Current application version:** `1.0.0+1`  
**Starting storage schema:** `2`  
**Current storage schema:** `3`

## 1. Executive decision

DevDesk should evolve incrementally from its existing feature-oriented Flutter application. A rewrite is neither necessary nor safe. The repository already contains valuable, tested foundations for API workspaces, Markdown notes, diffs, safe file access, protected secrets, backup recovery, responsive widgets, appearance customization, privacy consent, and release hardening.

The transformation will introduce a filesystem-backed **Developer Workspace** as the product's organizing boundary. Knowledge, API, OpenAPI, Git, search, and future AI/MCP capabilities will depend on stable domain interfaces rather than calling navigation, Hive, `dart:io`, HTTP, or processes from widgets.

The implementation is divided into the eleven required phases. Each phase has an explicit acceptance gate and phase ledger. A phase is complete only when its scoped behavior is implemented, tested, documented, and the existing regression suite remains green. Unsupported platform behavior must be disabled with an explanation; it must never report fake success.

## 2. Audit scope and evidence

The audit covered:

- all tracked and untracked source paths visible in the working tree;
- Flutter/Dart dependencies and generated platform registrations;
- application startup, routing, state management, theme, and privacy gates;
- Hive boxes, migrations, backup transaction and recovery behavior;
- external file detection, decoding, overwrite and Save As behavior;
- API request, workspace, variables, secrets, response, test and history code;
- Markdown and vault models, editor, parser, links, drafts, versions and export;
- diff, folder comparison, Git CLI and GitHub download services;
- Android manifest, network policy, backup policy, signing and Keystore bridge;
- Windows runner, DPAPI bridge, atomic replacement and dirty-window guard;
- the automated test inventory and prior senior audit reports.

### 2.1 Verified baseline

At the start of this product program:

| Check | Evidence | Status |
| --- | --- | --- |
| Static analysis | `flutter analyze` | Passed with no issues |
| Automated tests | `flutter test` | 333 tests passed |
| Windows release build | `flutter build windows --release` | Passed |
| Android debug build | `flutter build apk --debug` | Passed |
| Android release bundle | release signing guard | Correctly blocked until real signing material is supplied |
| Real Android device | no device evidence in this audit | Not verified |
| Windows installer/signing | no signed installer evidence | Not verified |

The older `docs/senior_audit` reports are retained as historical evidence. Their original 135-test and release-risk snapshot must not be treated as the present state: protected secret stores, bounded networking, transactional backup recovery, privacy consent, real-signing enforcement, richer theming, and many tests have since been added.

### 2.2 Working-tree constraint

The repository is already materially dirty with the owner's broader release work. Phase commits are therefore skipped until the tree can be separated safely. This avoids mixing or overwriting user changes. Every phase will still record changed files, tests, and risks in this document.

## 3. Current architecture summary

### 3.1 Runtime and state

- Flutter with Material 3 targets Android and Windows.
- Riverpod `2.3.2` provides application and feature state, primarily through `Provider`, `StateProvider`, and `StateNotifierProvider`.
- `main.dart` initializes Flutter, the Windows close guard, recoverable local storage, and the rating service before mounting `ProviderScope`.
- `MaterialApp` supplies persisted themes, a global command registry, generated named routes, and the privacy-acceptance gate.
- Navigation is currently a flat named-route switch in `lib/app/router.dart`. Feature screens own most local navigation and dialog behavior.

### 3.2 Persistence

- Hive/Hive Flutter stores settings, dashboard preferences, API data, snippets, Markdown files, vault notes, and internal recovery records.
- `LocalStorage` owns a known-box registry, schema version 2, migration journal, interrupted-import journal, rollback snapshots, quarantine, backup validation, and destructive reset.
- Shared Preferences is used by rating and privacy acceptance where small platform preference records are appropriate.
- Actual external documents are accessed through `file_picker`; the internal vault currently stores note bodies in Hive and can associate an external path, but it is not yet a true folder-backed workspace.

### 3.3 Files and platform code

- `ExternalFileService` recognizes bounded developer text formats, preserves text encoding and line endings, detects external edits by fingerprint, stages writes, verifies content, and creates recovery copies.
- Windows direct overwrite uses a native `ReplaceFileW` channel and rejects network paths, symlinks/reparse targets, identity changes, and unverifiable replacement.
- Android document access is picker/stream based. Direct overwrite of SAF document URIs is intentionally unavailable; Save As is used instead.
- `path` is available and already used for safe joins in critical file code.
- There is not yet a general workspace folder grant, file-watching, locking, normalization, or capability abstraction.

### 3.4 Security and networking

- API secrets use `SecureSecretStore` references rather than portable exports.
- Android protects values with AES-GCM keys generated in Android Keystore.
- Windows protects per-user values with DPAPI and stores encrypted blobs under Local App Data.
- `DataRedactor`, safe clipboard handling, archive traversal/size policy, and bounded HTTP reads are present.
- Android production cleartext traffic is disabled and system trust anchors are used. Debug has a separate development policy.
- There is no analytics or required backend.

### 3.5 UI and design

- A design-token layer supplies spacing, radius, typography, motion, shadows, breakpoints, semantic status/diff colors, and reusable application widgets.
- The theme engine persists system/light/dark mode, six accent palettes, system/standard/high contrast, comfortable/compact density, and a code-theme identifier.
- Reusable responsive shell, page, split-view, editor, result, card, error, empty and loading widgets exist.
- Large feature pages still contain many private widgets and business decisions; the API workspace page is roughly 3,700 lines and is a refactoring risk.

## 4. Current feature inventory

| Area | Present and reusable | Gap against target |
| --- | --- | --- |
| Dashboard | searchable tools, favourites, recents, quick actions | not workspace-centric; no unified activity/search |
| Appearance | six palettes, light/dark/system, contrast, density, semantic colors | code/editor/diff/graph theme selection and font controls need completion |
| Privacy/release UX | versioned privacy acceptance, privacy page/HTML, rating service, dormant commerce guard | store-hosted privacy URL and future billing adapters still external release work |
| Markdown utility | edit/preview, external Markdown, safe images | full split workflow, syntax decoration, workspace navigation and richer extensions incomplete |
| Markdown vault | notes/folders, tags, frontmatter map, wiki links/aliases, backlinks, outline, tabs, drafts, versions, quick switcher, command palette, export/templates | Hive is canonical; YAML parser is intentionally shallow/lossy; no real folder watcher, graph, unlinked mentions, stable path identity, or scalable index |
| API quick tester | methods, URL, headers/query/body, environments, history, response views, snippets | secondary path overlaps the richer workspace client |
| API workspaces | workspaces, collections/folders/requests, variables, secret refs, auth, assertions, extraction, runner, reports, imports/exports, bounded execution and cancellation | body/auth/import formats incomplete; cookie/proxy/TLS/certificate/large-response UX and OpenAPI absent |
| Diff checker | text/folder/GitHub sources, sessions/history, options and summaries | presentation is generic text diff; Git data not integrated into a repository workspace |
| Git | installed/repo checks, short status, file diff and HEAD content through Git CLI | no typed failures/capabilities, porcelain `-z`, branch/ahead/conflict/remote data, audit trail, recovery patches, staging/discard/commit |
| Files | bounded read, encoding/line-ending preservation, conflict check, atomic Windows replace, Save As | no folder abstraction, persisted Android folder grants, watch service, locking, large-file streaming |
| Storage/backup | versioned boxes, journaled migrations/import rollback, quarantine, redacted export | workspace/search/OpenAPI/Git caches need new schema and migrations; user files need a separate backup manifest |
| Utilities | JSON, JWT, regex, Base64, URL, timestamp, UUID, snippets, README generator | preserve as basic/free tools; connect to workspace where useful |
| Search | dashboard tool search and vault linear title/content search | no unified index, fuzzy/filter/saved search, incremental updates, or semantic-ready interface |
| OpenAPI | no first-class implementation | complete phase required |
| OKF | frontmatter and Markdown primitives only | complete spec-aware service, validation, generation, templates and dashboard required |
| AI/MCP | no provider dependency | interfaces, privacy boundary and proposal workflow required; default remains disabled |

## 5. Reusable components

The following are architectural assets and must be extended rather than replaced:

1. `LocalStorage`, `BackupUtils`, migration/import journals and quarantine.
2. `ExternalFileDocument`, `ExternalFileDetector`, and safe external save behavior.
3. `SecureSecretStore` with Android Keystore and Windows DPAPI bridges.
4. `BoundedHttpReader`, cancellation token, response ceiling and timeout behavior.
5. `ArchivePolicy` for ZIP validation and traversal/bomb limits.
6. `DataRedactor` and safe clipboard boundary.
7. `AppThemeFactory`, `ThemePreferences`, `AppPalette`, semantic colors and design tokens.
8. Responsive widgets and breakpoint conventions.
9. API workspace models, composer, variable resolver, auth resolver, assertion/extraction evaluators, storage and runner.
10. `VaultNote`, draft/version behavior, wiki parsing, backlink calculation, editor/preview/inspector/sidebar interactions.
11. `DiffUtils`, diff models, folder diff and GitHub URL/archive protections.
12. Global command registry and Windows dirty-document close guard.

## 6. Technical debt and fragile areas

### 6.1 Architecture

- Feature widgets directly coordinate persistence, process, file and network behavior in several places.
- Models and providers often combine domain, storage serialization, UI state and orchestration.
- Flat string routes do not model workspace identity or cross-feature references.
- `StateNotifier` is workable but several notifiers are large and eager; future work should use narrowly scoped immutable state without a framework-wide rewrite.
- API quick tester and API workspaces overlap. They require a shared execution domain, not a second implementation.

### 6.2 Knowledge and YAML

- The current frontmatter parser accepts a small YAML-shaped subset, silently ignores malformed lines, and rewrites values without preserving comments, quoting, ordering, nested objects, scalar types, anchors, or unknown formatting.
- Vault note identity is title-oriented; renames and duplicate titles make durable links ambiguous.
- Link/backlink calculation scans all note bodies and does not scale to thousands of files.
- The canonical note body is frequently opaque Hive data rather than the user's workspace file.
- Draft persistence exists, but external-file crash recovery and conflict merging require a workspace journal.

### 6.3 API

- The core is substantial, but storage and UI models are large and tightly coupled.
- Current body types are none, JSON, text, URL-encoded and field-only multipart. XML, YAML, HTML, binary, file parts and GraphQL need typed support.
- Auth lacks OAuth 2.0 and custom-header profiles.
- Response data is bounded but still materialized in memory for presentation/storage; full-response-to-file streaming is not exposed.
- Import compatibility claims must remain format- and fixture-specific.

### 6.4 Git

- Git calls use direct `Process.run`, suppress some errors, and parse human-oriented short status text rather than NUL-delimited porcelain.
- Renames, quoted paths, conflicts, repository discovery errors, timeouts and cancellation are not modeled robustly.
- Android does not normally provide a Git executable; capabilities must be detected and unsupported actions disabled.
- Destructive actions, credential prompting, recovery patches and audit records do not exist.

### 6.5 Quality and performance

- Several pages are too large for safe independent testing and maintenance.
- Search and backlink operations are linear/eager.
- Markdown, YAML, OpenAPI, graph and large-diff parsing need isolate/cancellation thresholds.
- The current test suite is strong for its size but does not cover the requested folder-workspace, OKF, OpenAPI, unified index, or safe Git workflows because they do not exist yet.

## 7. Risk register

| ID | Severity | Risk | Required control |
| --- | --- | --- | --- |
| DW-001 | Critical | workspace migration or delete damages user files | metadata removal and file deletion are separate; atomic manifests, preview, explicit typed confirmation, recovery backup |
| DW-002 | Critical | Android folder access is assumed to behave like Windows paths | platform capability interface; persisted grant/URI model; Save As fallback; Android tests |
| DW-003 | Critical | secrets leak into Markdown, backup, logs, request history or diagnostics | secret references only; redaction at every portable sink; fixture tests; explicit reveal/copy |
| DW-004 | High | malformed or complex YAML is silently damaged | standards-capable safe YAML parser; raw-slice preservation; round-trip fixtures; no arbitrary constructors |
| DW-005 | High | Git discard/stage acts on a different worktree state | status fingerprint, preview, pathspec-safe invocation, recovery patch, confirmation, postcondition verification |
| DW-006 | High | Git command execution becomes arbitrary process execution | allowlisted executable/arguments, no shell, bounded output/time, canonical repo boundary |
| DW-007 | High | large files/responses/specs/diffs exhaust memory or block UI | hard ceilings, streaming-to-file, pagination, isolate thresholds, cancellation, truncation disclosure |
| DW-008 | High | filesystem and Hive records drift after external edits/interrupted writes | content fingerprint, journal, incremental rescan, conflict state and deterministic recovery |
| DW-009 | High | OKF implementation over-validates a permissive draft standard | versioned rules and severity policy; preserve unknown fields/types; best-effort consumption |
| DW-010 | High | phase breadth creates shallow or fake UI | domain/service and tests first; expose only completed capability; record limitations |
| DW-011 | Medium | flat navigation cannot resolve durable cross-feature links | typed route destinations and central reference resolver |
| DW-012 | Medium | indexing thousands of files creates stale results | per-workspace generations, incremental transactions, corruption rebuild, observable progress |
| DW-013 | Medium | AI/cloud sends private content without consent | provider-disabled default, capability disclosure, per-operation approval, redaction preview |
| DW-014 | Medium | future subscription blocks essential local data access | entitlement abstraction stays dormant; opening/editing/exporting owned data and core tools remain free |

No phase may proceed past an unresolved critical data-loss or secret-storage failure.

## 8. Proposed architecture

### 8.1 Layering

```text
Presentation (pages, panels, dialogs, adaptive shell)
        |
State (small Riverpod controllers and immutable view state)
        |
Application (use cases, commands, query orchestration, capability policy)
        |
Domain (workspace, knowledge, API, OKF, OpenAPI, Git, search, references)
        |
Repositories (interfaces and mapping; no widgets or Navigator)
        |
Infrastructure (Hive, filesystem/SAF, Git CLI, HTTP, secure storage, isolates)
```

Rules:

- Domain and application layers do not import Flutter widgets.
- UI does not call `Process.run`, Hive boxes, platform channels, raw file writes, or HTTP clients directly.
- All external operations accept cancellation where useful and return typed results/failures.
- Workspace files remain the canonical source for Markdown/YAML/JSON/OpenAPI/source artifacts.
- Hive stores indexes, UI state, metadata, history and caches with human-readable export paths.
- Writes to user files are atomic or explicitly Save As; preconditions and recovery are recorded.
- Navigation is requested through typed destinations. Markdown rendering never contains route switch logic.

### 8.2 Module boundaries

```text
lib/
  app/                 composition, routes, adaptive shell, commands, theme
  core/
    errors/            typed failures and diagnostic envelopes
    files/             platform-neutral file/folder capabilities
    logging/           structured privacy-safe audit/application events
    security/          secret refs, redaction, clipboard, archive policy
    storage/           schema, migrations, backup and recovery
  features/
    workspaces/        workspace domain, registry, health, backup
    knowledge/         file index, Markdown model/editor/link graph
    okf/               versioned OKF rules, validator, generators, dashboard
    api_tester/        existing API domain split into focused modules
    openapi/            parser, validation, generation, comparison
    git/               repository capability/status/diff/action adapters
    search/            unified index/query/saved searches
    references/        URI parser, validation and typed destination resolver
    activity/          auditable user and system events
    ai/                optional provider contracts and proposal workflow
    mcp/               future read/write-separated application facade
```

Existing folders will be migrated gradually. Imports or files will not be moved merely for cosmetic consistency.

### 8.3 Core interfaces

The foundation will introduce or stabilize these boundaries:

```dart
abstract interface class WorkspaceRepository {}
abstract interface class WorkspaceFileSystem {}
abstract interface class WorkspaceIndexRepository {}
abstract interface class KnowledgeRepository {}
abstract interface class OkfService {}
abstract interface class ApiWorkspaceRepository {}
abstract interface class OpenApiService {}
abstract interface class GitRepositoryService {}
abstract interface class SearchService {}
abstract interface class ReferenceResolver {}
abstract interface class ActivityRepository {}
abstract interface class AiProvider {}
```

Interfaces are intentionally capability-oriented. Android and Windows adapters may advertise different support; unsupported methods return a typed capability failure.

## 9. Data model plan

### 9.1 Workspace

```text
DeveloperWorkspace
  id: stable UUID
  schemaVersion: int
  name, description, iconId
  root: WorkspaceRootRef (Windows path or Android persisted document-tree ref)
  kinds: set<git, documentation, okf, api, mixed>
  createdAt, lastOpenedAt
  pinned
  settings: WorkspaceSettings
  healthSnapshot: WorkspaceHealthSummary?
  indexGeneration
```

`WorkspaceRootRef` must never serialize Android URIs as if they were ordinary file paths. It records platform, opaque grant/path identifier, display path, capability set, and optional canonical local path.

Removal from DevDesk deletes only registry/cache records. `DeleteWorkspaceFilesCommand` is a distinct, high-friction operation and is unavailable where recursive deletion cannot be proven safe.

### 9.2 Knowledge

```text
KnowledgeDocument
  id: WorkspaceDocumentId(workspaceId + normalized relative path)
  stableId: optional producer field
  relativePath, fileName, extension
  title, description, type, tags
  frontmatter: FrontmatterDocument(raw slice + typed projection + unknown fields)
  contentFingerprint, modifiedAt, indexedAt
  outgoingReferences, backlinkCount
  draftState, conflictState, validationState
```

The raw frontmatter slice is retained independently of the typed projection. Form edits patch only intended fields and preserve unknown data whenever safe. A parse error blocks form write-back but keeps raw editing available.

### 9.3 OKF

```text
OkfBundleDescriptor(version, root, detectionEvidence)
OkfConcept(documentId, conceptId, type, recommended fields, extensions)
OkfValidationIssue(code, severity, documentId, location, message, remediation)
OkfHealthReport(counts, issues, generatedAt, sourceGeneration)
OkfGenerationPlan(createdFiles, updatedSections, skippedCustomContent)
```

OKF rules are versioned. For official draft v0.1:

- a bundle is a directory tree of UTF-8 Markdown files with YAML frontmatter;
- every non-reserved concept document requires a non-empty `type`;
- unknown types and fields are tolerated and preserved;
- `index.md` and `log.md` are reserved and optional;
- missing indexes and broken links are guidance/diagnostic findings, not bundle rejection;
- index/log generation never overwrites custom prose and always previews a plan.

The user-requested stable IDs, review, verification, ownership, version and deprecation fields are DevDesk-compatible extensions, not claimed OKF v0.1 requirements.

### 9.4 API and OpenAPI

Existing `ApiWorkspace`, `ApiCollection`, `ApiFolder`, `ApiRequestItem`, environment, variable, auth, assertion, extraction, response and history models remain migration inputs.

New models will separate:

- request definition from a resolved/prepared execution;
- body variants and file references;
- secret-bearing auth configuration from portable secret references;
- bounded response metadata from optional body storage/file handles;
- import source, compatibility warnings and canonical source references;
- OpenAPI document identity, operation pointer, schema pointer and generation fingerprint.

Variable priority will be deterministic and visible:

```text
request temporary/extracted > request > collection > environment > workspace > global
```

Duplicate names at the same level are validation errors. Secret values resolve only at execution time and never appear in previews by default.

### 9.5 Git

```text
GitRepositorySnapshot
  root, branch, detachedHead, upstream, ahead, behind
  headCommit, remote summaries, cleanliness, conflicts
  entries: GitStatusEntry(path, originalPath, indexStatus, worktreeStatus)
  fingerprint

GitActionPlan
  action, repositoryFingerprint, selected paths/hunks
  previewPatch, recoveryPatchPath?, warnings, requiredConfirmation

GitAuditEvent
  id, timestamp, action, repositoryId, redacted targets, outcome, recoveryRef
```

Git credentials remain owned by the system Git credential manager. DevDesk will not prompt for or persist raw credentials in ordinary application storage.

### 9.6 Search and references

```text
SearchDocument(id, workspaceId, kind, title, bodyTerms, metadataTerms,
               tags, status, modifiedAt, sourceGeneration, payloadRef)
SavedSearch(id, workspaceId, name, query, filters)
WorkspaceReference(scheme, authority, pathSegments, query, fragment)
ResolvedReference(reference, status, destination?, explanation)
```

Search is behind a `SearchService`; the first implementation is deterministic local lexical/fuzzy search. Semantic embeddings are a future adapter, not a default dependency.

### 9.7 AI/MCP proposal

```text
AiProviderCapabilities
AiRequest / AiResult / AiChunk
ContentDisclosurePlan
WorkspaceChangeProposal
ValidatedWorkspacePatch
ProposalApproval
```

Write operations follow propose, validate, preview diff, approve, atomic write, Git visibility, index update, and audit. Read and write MCP facades are separate.

## 10. Navigation and interaction structure

### 10.1 Primary areas

- Home
- Workspaces
- Knowledge
- API
- Git
- Search
- Activity
- Settings

Utilities remain available from Home and the command palette. Existing named routes remain compatible while typed route arguments and workspace destinations are introduced.

### 10.2 Android

- Bottom navigation for the most frequent workspace areas, with overflow/drawer for Activity and Settings.
- Full-screen focused editors/builders; contextual panels open as sheets or full routes.
- One-pane knowledge navigation with breadcrumb and document switcher.
- Predictive/system back must unwind panels, drafts and workspace navigation safely.
- Touch targets remain at least 44–48 logical pixels; compact/freeform windows must reflow without horizontal overflow.
- Folder capabilities reflect Android document provider grants; no unrestricted storage assumption.

### 10.3 Windows

- Persistent navigation rail/sidebar plus workspace switcher.
- Resizable explorer/editor/inspector panels, tabs and optional split editor/preview.
- Keyboard shortcuts, hover, context menus, drag/drop where the platform adapter supports it.
- Window close is blocked while recoverable dirty documents exist.
- Window size/panel widths/tabs persist as UI state; architecture remains multi-window-ready without claiming multi-window support.

### 10.4 Typed destinations

Examples include `WorkspaceHomeDestination`, `KnowledgeDocumentDestination`, `ApiRequestDestination`, `OpenApiOperationDestination`, `GitDiffDestination`, and `SearchDestination`. The central reference resolver maps `api://`, `git://`, `workspace://`, and `okf://` references to these destinations.

## 11. Phase plan and acceptance gates

### Phase 1 — Audit and architecture

Deliverables:

- complete repository and platform audit;
- current inventory, reuse/debt/risk decisions;
- proposed layers, data models and navigation;
- migration/test/platform/release plans;
- verified baseline recorded in this document.

Acceptance gate: this document exists, accurately distinguishes current features from gaps, and no large implementation preceded it.

**Status: complete.**

### Phase 2 — Foundation

Scope:

- introduce `DeveloperWorkspace`, root reference, capability model, registry/repository and health summary;
- create platform filesystem interface for paths, grants, reads, atomic writes, watch/capability detection and safe delete planning;
- add storage schema migration and rollback tests for workspace/index/activity records;
- expand the typed failure taxonomy and privacy-safe structured logger;
- add an adaptive workspace shell using existing tokens, palettes and responsive primitives;
- preserve all current routes and utilities.

Acceptance gate: create/import/open/remove-metadata workspace flows work without deleting source files; migration rollback is tested; compact Android and expanded Windows widget matrices pass.

**Status: complete.** The platform contract includes opaque document-tree roots for a future Android SAF adapter; the current picker adapter registers ordinary paths only when the platform returns a real directory. Unsupported document-tree operations fail with a typed capability message rather than treating a URI as a Windows-style path.

### Phase 3 — Markdown knowledge system

Scope:

- make workspace Markdown files canonical while providing a compatibility adapter for Hive vault notes;
- introduce robust frontmatter document parsing and conservative patching;
- add editor/preview/split, auto-save debounce, manual save, dirty/recovery/conflict state;
- index wiki links, standard links, backlinks, outline, tags, mentions, orphans, broken links and duplicate titles;
- add explorer, quick open, tabs/switcher, panels, history and workspace search;
- add bounded graph projection with platform-appropriate gestures.

Acceptance gate: a filesystem workspace can edit/recover Markdown, preserve unknown frontmatter, resolve backlinks, and remain responsive in large fixture tests.

### Phase 4 — OKF support

Scope:

- implement versioned OKF v0.1 detection and validation service;
- detect required `type`, YAML/timestamp problems, duplicates, orphans, links, review/deprecation extension rules and optional index/log guidance;
- implement preview-first root/folder index and log generation preserving custom content;
- add templates and health dashboard/report export.

Acceptance gate: official-style minimal/permissive fixtures and invalid fixtures pass; unknown fields/types round-trip; missing index and broken link severity follows the draft spec.

### Phase 5 — API client upgrade

Scope:

- consolidate quick and workspace executors behind one domain boundary;
- complete body variants, cookie model, auth profiles, request metadata and safe platform capability settings;
- formalize variable layers/autocomplete/undefined warnings and protected secret refs;
- improve collection tree, native JSON/cURL/HAR/Postman fixture-tested imports/exports;
- add large-response file streaming/truncation, response search/compare/export/docs;
- complete history retention/privacy controls and structured test results.

Acceptance gate: current API regression tests pass; every claimed import format has fixtures; secrets never enter portable data; bounded request execution can cancel.

### Phase 6 — OpenAPI integration

Scope:

- safe bounded JSON/YAML import and validation;
- path/schema explorer;
- deterministic request and example generation with source fingerprints;
- link Markdown/OKF concepts to JSON Pointer operations;
- compare two specifications and classify tested breaking changes;
- generate Markdown docs without mutating the canonical specification.

Acceptance gate: OpenAPI 3 fixture corpus imports, generates, links and compares deterministically; unsupported constructs produce explicit warnings.

### Phase 7 — Git experience

Scope:

- replace loose static calls with capability-aware Git repository service;
- parse NUL-delimited porcelain status and typed command failures;
- add branch/upstream/ahead/conflict/remote/last-commit status;
- implement unified/side-by-side adaptive diff, hunk navigation and semantic Markdown diff;
- add previewed file/hunk stage/unstage/discard, commit and safe branch/fetch/pull/push where supported;
- generate recovery patches and audit destructive operations.

Acceptance gate: temp-repository integration tests verify special paths, conflicts, stale-state rejection, stage/unstage/discard recovery and unsupported Android behavior. Force push is absent.

### Phase 8 — Unified linking and search

Scope:

- implement typed reference schemes and central resolver;
- link knowledge, API, OpenAPI, Git, environment and test entities;
- add incremental unified index, fuzzy/exact/filter queries, history and saved searches;
- add Activity backed by privacy-safe audit/application events.

Acceptance gate: reference navigation contains no renderer-specific route switch; broken references are diagnosable; index rebuild/incremental update equivalence is tested.

### Phase 9 — AI and MCP-ready architecture

Scope:

- define provider capability, completion/stream, cancellation, timeout, size and disabled-mode interfaces;
- add disclosure/redaction/consent policies and local/cloud provider slots without a forced provider;
- implement proposal validation, diff preview and explicit approval workflow;
- expose read/write-separated MCP-ready application operations without starting a silent server.

Acceptance gate: disabled mode leaves all core features useful; no external provider receives content without an approved disclosure plan; writes cannot bypass proposal approval.

### Phase 10 — Hardening

Scope:

- performance fixtures and measurements for thousands of documents, large Markdown/JSON/spec/diff/response data;
- isolate/cancellation/pagination/cache tuning;
- security, path, archive, YAML/JSON/OpenAPI, URL credentials, TLS and redaction review;
- accessibility semantics, focus order, keyboard/touch targets, contrast and text scaling;
- interrupted writes, migration, corrupted cache, external edit and recovery tests;
- Android emulator/device and Windows runtime checks when evidence is available.

Acceptance gate: no open critical security/data-loss issue; analyzer/tests/builds pass; performance budgets and unsupported device evidence are documented truthfully.

### Phase 11 — Release preparation

Scope:

- run formatting check, analyzer, full tests, migration tests and Android/Windows builds;
- verify privacy, export/import, licensing, versioning, signing prerequisites and store metadata;
- complete all eleven required guides/reports and README;
- produce a complete ZIP of changed/new files with manifest and SHA-256;
- list known limitations and unverified hardware/distribution steps.

Acceptance gate: release report contains commands/results/artifact hashes; Android production output is not claimed without real signing; Windows distribution is not claimed signed unless verified.

## 12. Migration strategy

1. Keep schema 2 readable while Phase 2 introduces a schema 3 registry through an additive migration.
2. Snapshot affected Hive boxes before each migration and retain the existing journal/rollback pattern.
3. Add new boxes only through the central known-box registry; every record includes a schema version where independently evolvable.
4. Treat existing Hive vault notes as legacy internal workspaces. Do not silently move or delete them.
5. Offer an explicit export/migration preview from internal notes to a selected folder. Verify file counts and fingerprints before marking migration complete.
6. Keep old API workspace deserializers tolerant. Introduce adapters and default new fields rather than destructive rewrites.
7. Migrate legacy inline secrets into protected storage before serializing the sanitized replacement. Failure leaves the original data recoverable and does not log values.
8. Search, Git and validation data are rebuildable caches. Corruption discards only the cache after confirmation/diagnostic recording, never workspace source files.
9. Workspace removal deletes registry, UI state and rebuildable cache only. Source deletion is a separate previewed command.
10. Backups include a versioned metadata manifest. Workspace file archives are optional, traversal-safe, bounded, previewed and restored to a newly selected target by default.

## 13. Testing strategy

### 13.1 Test pyramid

- Unit tests own parsers, normalization, validation, variable/auth composition, redaction, diff/reference/search logic, error mapping and migration transforms.
- Widget tests own adaptive layout, editor state, dashboards, builders/viewers, command palette, focus and accessibility behavior.
- Integration tests use temporary directories, Hive stores, local HTTP servers and temporary Git repositories. They must not depend on a user's repository or network service.
- Platform channel tests use deterministic adapters. Native runtime checks are recorded separately and never inferred from mocks.

### 13.2 Required regression groups

- all existing 333 tests;
- workspace create/import/open/remove/backup/restore/health;
- path normalization, grant/capability and atomic-write recovery;
- frontmatter and wiki/standard link fixtures, including unknown YAML preservation;
- OKF v0.1 conformance/permissive behavior/index/log fixtures;
- API variable/auth/secret/request/response/history/import fixtures;
- OpenAPI import/generation/link/comparison fixtures;
- Git status/diff/action temp-repository tests;
- unified reference and index rebuild/incremental equivalence;
- AI disclosure and proposal-approval policy;
- compact/medium/expanded responsive and text-scale matrices.

### 13.3 Quality commands

Each phase runs the smallest relevant tests during development, then:

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Builds are required at hardening/release and after native/dependency changes:

```text
flutter build apk --debug
flutter build windows --release
flutter build appbundle --release   # only with real signing configured
```

## 14. Platform-specific considerations

### 14.1 Android

- Use Storage Access Framework/document-tree grants for user-selected folders; persist and revalidate grants where the plugin/native adapter supports it.
- Never infer a stable ordinary path from a content URI.
- Git process actions are disabled unless an explicit tested implementation/capability exists.
- Keystore availability is API 23+, matching the secure-store bridge assumption; failures are typed and secrets are not downgraded to plaintext.
- Production cleartext remains disabled. Local HTTP development must be an explicit debug/developer capability, not a silent release exception.
- Freeform, split-screen, keyboard, back handling, lifecycle draft persistence and provider revocation require tests.

### 14.2 Windows

- Canonicalize repository/workspace roots and defend against reparse points before destructive actions.
- Continue using DPAPI for protected values and `ReplaceFileW` for verified same-volume replacement.
- Git CLI operations use `Process.run` directly with allowlisted arguments, never `cmd.exe` or shell interpolation.
- Support drive/UNC distinctions; direct atomic overwrite of network paths remains disabled unless a tested recovery contract is introduced.
- Keyboard, hover, right-click, resizable panels, focus traversal, window close and artifact contents require runtime checks.

### 14.3 Cross-platform contract

Capability detection is first-class. The UI may vary, but stored workspace/reference data remains portable. Platform-specific identifiers are carried in tagged root references; paths are normalized only within the correct adapter.

## 15. Security and privacy controls

- No analytics, cloud account or AI provider is required.
- Network calls occur only for user-run API/GitHub/import/sync/provider actions and are visibly attributed.
- Secrets use opaque references and platform-protected storage; no Markdown/frontmatter storage.
- Logs use codes, correlation IDs and redacted structured fields; raw exceptions are developer-only and sanitized before support export.
- Imported archives/specs/YAML/JSON are size-bounded and parsed without arbitrary code or object construction.
- URL user-info and known credential query/header names are detected and masked.
- TLS verification stays enabled. Any future insecure-TLS setting is a session-scoped, explicit warning and never default.
- Imported scripts are data only. API assertions use safe declarative evaluators.
- Subscription readiness cannot block users from opening, editing, backing up, restoring or exporting their own local data.

## 16. Product/free and future Pro boundary

Billing remains disabled until real Android and Windows commerce adapters, entitlement verification, restore-purchase flows, privacy/store disclosures and tests exist.

Always-free capabilities:

- opening and editing local files/workspaces;
- core Markdown, JSON and developer utilities;
- basic API requests and local collections;
- basic Git status/diff viewing where supported;
- import/export/backup/restore of user data;
- privacy, security and accessibility controls.

Potential future Pro capabilities:

- advanced graph analytics and very large index acceleration;
- collection runners and advanced API reports;
- OpenAPI breaking-change reports and bulk documentation generation;
- advanced Git semantic comparisons and workflow automation;
- optional AI/provider integrations and team-oriented templates.

The entitlement layer must be injectable and dormant. No placeholder pay button may imply purchasing works.

## 17. Documentation deliverables

Phase 11 must verify and complete:

- `docs/FUTURISTIC_DEVELOPER_WORKSPACE_IMPLEMENTATION_PLAN.md`
- `docs/ARCHITECTURE.md`
- `docs/OKF_WORKSPACE_GUIDE.md`
- `docs/MARKDOWN_KNOWLEDGE_GUIDE.md`
- `docs/API_CLIENT_GUIDE.md`
- `docs/OPENAPI_INTEGRATION_GUIDE.md`
- `docs/GIT_WORKFLOW_GUIDE.md`
- `docs/SECURITY_AND_PRIVACY.md`
- `docs/ANDROID_WINDOWS_PLATFORM_NOTES.md`
- `docs/AI_AND_MCP_READINESS.md`
- `docs/TESTING_AND_RELEASE_REPORT.md`

README, known limitations, keyboard shortcuts, and import/export instructions may link to these canonical documents rather than duplicate them.

## 18. Release-readiness checklist

### Product and data

- [ ] Workspace removal cannot delete source files.
- [ ] Explicit source deletion has preview, confirmation, boundary proof and recovery story.
- [ ] Existing Hive vault/API/settings data migrates with rollback tests.
- [ ] Every user-owned artifact has a human-readable export path.
- [ ] External edit and interrupted write recovery are verified.

### Security and privacy

- [ ] No secret appears in Hive portable records, Markdown, logs, history export or support export.
- [ ] Android Keystore and Windows DPAPI runtime behavior is verified.
- [ ] Archive, YAML, JSON, OpenAPI, path and URL input limits are tested.
- [ ] Privacy policy accurately names optional network features and future AI consent behavior.
- [ ] No telemetry or silent remote request exists.

### Functionality

- [ ] Workspace, knowledge, OKF, API, OpenAPI, Git, linking and search gates pass.
- [ ] Unsupported platform actions are visibly disabled.
- [ ] AI/provider-disabled mode is complete and useful.
- [ ] Destructive Git and AI proposals require diff preview and approval.

### Quality

- [ ] Formatting check passes.
- [ ] Analyzer passes.
- [ ] Existing and new tests pass without deletion/weakening.
- [ ] Android compact/freeform and Windows expanded widget matrices pass.
- [ ] Performance budgets and large-fixture results are recorded.
- [ ] Accessibility semantics, focus, contrast and text scaling are checked.

### Distribution

- [ ] Version/changelog/known limitations are current.
- [ ] Android release uses owner-supplied real signing and store privacy URL.
- [ ] Windows portable/installer contents, VC runtime requirements and signing state are documented.
- [ ] Artifact hashes and reproducible commands are recorded.
- [ ] Complete changed/new-file ZIP includes a manifest and excludes secrets/build caches.

## 19. Phase ledger

### Phase 1 ledger — 2026-07-22

**Files changed**

- Added `docs/FUTURISTIC_DEVELOPER_WORKSPACE_IMPLEMENTATION_PLAN.md`.

**Tests added**

- None; Phase 1 is an audit/documentation phase.

**Tests/checks executed or carried into the verified starting baseline**

- `flutter analyze` — passed.
- `flutter test` — 333 passed.
- `flutter build windows --release` — passed.
- `flutter build apk --debug` — passed.
- Android release signing guard — correctly blocks unsigned/debug-signed release output.

**Remaining risks**

- The requested product scope remains unimplemented beyond the existing baseline; Phases 2–11 are open.
- No real Android device or signed Windows distribution was tested.
- The working tree contains pre-existing owner changes, so no clean phase commit was created.
- OKF is version 0.1 Draft and may evolve; implementation must keep rules versioned and permissive.

**Commit**

- Skipped because the pre-existing dirty working tree cannot be cleanly attributed to this phase.

### Phase 2 ledger

**Status: complete — 2026-07-22.**

**Files changed**

- Added `lib/features/workspaces/domain/workspace_models.dart`.
- Added `lib/features/workspaces/domain/workspace_repository.dart`.
- Added `lib/features/workspaces/domain/workspace_file_system.dart`.
- Added `lib/features/workspaces/data/hive_workspace_repository.dart`.
- Added `lib/features/workspaces/data/local_workspace_file_system.dart`.
- Added `lib/features/workspaces/provider/workspace_provider.dart`.
- Added `lib/features/workspaces/presentation/workspaces_page.dart`.
- Added `lib/core/logging/structured_logger.dart`.
- Added `test/features/workspaces/workspace_foundation_test.dart`.
- Updated `lib/core/storage/local_storage.dart` with additive schema 3 workspace, metadata, index and activity registries.
- Expanded `lib/core/errors/failure.dart` with typed parsing, storage, file, permission, platform, Git, migration and search-index failures.
- Updated dashboard tools, global commands, routes and responsive matrix coverage.

**Implemented behavior**

- Stable workspace ID, root, platform, capability, settings, kind, health and summary models.
- Workspace search, recent ordering, pinning, selection and duplicate-root prevention.
- Named workspace creation over a selected folder and existing-folder import.
- Metadata-only removal with explicit UI copy that source files remain untouched.
- Folder health checks without modifying source content.
- Traversal-safe relative paths, symlink avoidance, bounded listing/read, exclusive create, Windows-advertised atomic text replacement and capability-gated watching.
- Privacy-safe bounded structured-log events.
- Compact list/detail sheet and expanded split-view workspace UI.

**Tests added**

- Workspace model round trip.
- Non-mutating folder health probe.
- Safe bounded create/read/list and traversal rejection.
- Metadata removal preserves the entire source folder.
- Schema 2-to-3 migration is additive and preserves existing settings.
- Duplicate root registration reuses the existing workspace.
- Structured logs redact secrets and enforce retention capacity.
- Responsive matrix now includes Workspaces at five viewport classes and 200% text.

**Tests/checks executed**

- `dart format` for changed Dart files — clean.
- `flutter analyze` — no issues.
- Focused workspace foundation tests — 7 passed.
- Storage transaction tests — passed.
- Responsive matrix — passed, including 280 px graceful minimum, phone, landscape, freeform, compact desktop and 200% text.
- Full `flutter test` regression suite — passed.

**Remaining risks**

- Android persisted document-tree grants require a dedicated SAF adapter before document-tree roots can be edited; opaque document-tree roots are modeled but not faked as paths.
- No real Android device interaction or Windows folder-picker runtime interaction was performed in this phase.
- Filesystem watching is capability-gated and has not yet been connected to an incremental index.
- Atomic workspace text replacement is limited to the existing verified Windows path implementation; unsupported adapters fail explicitly.

**Commit**

- Skipped because the pre-existing dirty working tree cannot be cleanly attributed to this phase.

### Phase 3 ledger

**Status: complete — 2026-07-22.**

**Files changed**

- Added the `lib/features/knowledge/domain`, `data`, `provider`, and `presentation` modules.
- Added `yaml` as a direct safe-parser dependency.
- Added `/knowledge` routing and connected registered workspaces to the knowledge screen.
- Added `test/features/knowledge/knowledge_domain_test.dart`.
- Added `test/features/knowledge/workspace_knowledge_repository_test.dart`.
- Added `test/features/knowledge/knowledge_workspace_provider_test.dart`.

**Implemented behavior**

- Filesystem-backed Markdown indexing with bounded document/count/aggregate-size limits.
- Path-based document IDs, nested folder discovery and configurable excluded folders.
- Standards-capable safe YAML parsing plus targeted top-level form patches that preserve unknown fields, nested extensions, unrelated comments and raw editing.
- Wiki aliases/headings, standard relative links, backlinks, outgoing links, broken links, duplicate titles/stable IDs, orphans, unlinked mentions and tag-related documents.
- Edit, preview and split modes; Markdown syntax decoration; heading/checklist/table/code/wiki-link helpers; outline navigation; quick-open; workspace and current-file search.
- Windows-style tabs and expanded explorer/editor/inspector layout; compact document switcher and focused mobile layout.
- Autosaved drafts, closure recovery, stale-draft conflict disclosure, expected-fingerprint save and Windows dirty-close integration.
- Focused graph view capped at 80 selected/neighbour nodes with pan, mouse/pinch zoom, tooltips and node navigation.
- Keyboard shortcuts for save, quick open and find.

**Tests added**

- 8 parser/link/graph unit tests.
- 4 real temporary-workspace repository/recovery tests.
- 3 provider draft/conflict/save tests.
- Compact 320 px and expanded 1200 px knowledge widget tests.

**Tests/checks executed**

- `flutter analyze` — no issues.
- Knowledge test group — 17 passed.
- Existing workspace/storage/responsive tests — passed.

**Remaining risks**

- Android document-tree editing remains capability-disabled pending a persisted SAF adapter; no URI is misrepresented as a path.
- Local workspace images remain blocked in preview until path-boundary and content-size decoding are completed; remote tracking images remain intentionally blocked.
- Windows drag/drop link insertion and Android file-picker link insertion are not yet runtime-verified.
- Large-workspace parsing remains bounded but synchronous; isolate/incremental tuning is Phase 10 work.

**Commit**

- Skipped because the pre-existing dirty working tree cannot be cleanly attributed to this phase.

### Phase 4 ledger

**Status: complete — 2026-07-22.**

**Files changed**

- Added versioned OKF domain models, validator, template service and preview-first workspace generation service under `lib/features/okf`.
- Added the responsive OKF health dashboard and `/okf` route.
- Added `test/features/okf/okf_service_test.dart`.

**Implemented behavior**

- Draft OKF 0.1 detection and conformance validation.
- Required `type`, malformed YAML, invalid timestamp, duplicate stable-ID, broken-link, orphan, review, verification and deprecation-extension diagnostics.
- Error/warning/recommendation/information severities.
- Optional root/folder index planning with a marked managed section that preserves all custom prose.
- Optional dated log planning, preview and safe apply.
- Thirteen requested concept templates and JSON health-report export.
- Health metrics for concepts, valid concepts, errors, warnings, unverified, review due and deprecated.

**Standards decision**

- Missing `index.md` and broken links are not conformance errors.
- `index.md` and `log.md` remain optional reserved files.
- Unknown fields and unknown types are accepted.
- Stable ID, review, verification and deprecation rules are explicitly DevDesk extensions.

**Tests added/executed**

- 5 OKF validator/generator/template tests passed.
- Knowledge + OKF focused group — 22 passed.
- `flutter analyze` — no issues.

**Remaining risks**

- OKF remains a version 0.1 draft; rules are isolated in a versioned validator for future change.
- Generation is sequential; a multi-file plan can partially apply if a later file changes externally. Per-file writes remain safe, and transactional multi-file recovery is retained for Phase 10.
- No real Android/Windows dashboard runtime interaction was claimed.

**Commit**

- Skipped because the pre-existing dirty working tree cannot be cleanly attributed to this phase.

### Phase 5 ledger

**Status: complete — 2026-07-22.**

- Added XML, HTML, YAML, and GraphQL request bodies with preflight validation and correct media types.
- Preserved existing collections, environments, secret overlays, assertions, extraction rules, cancellation, bounded responses, and history.
- Added security regression tests for malformed structured bodies, GET/HEAD multipart rejection, URL credentials, and explicit content types.
- Deliberately left proxy, custom certificates, binary multipart attachments, and response streaming to file disabled and documented.
- Commit skipped because the repository contained pre-existing owner changes.

### Phase 6 ledger

**Status: complete — 2026-07-22.**

- Added bounded OpenAPI 3.x JSON/YAML parsing, operation/schema browsing, JSON Pointer source references, API collection generation, linked Markdown generation, and structural change comparison.
- Added a responsive OpenAPI Studio, dashboard/command routing, one-click import into API Workspaces, parser tests, comparison tests, and compact/desktop widget tests.
- Source specifications remain canonical and are never mutated.
- Commit skipped because the repository contained pre-existing owner changes.

### Phase 7 ledger

**Status: complete — 2026-07-22.**

- Replaced line-based Git parsing with canonical-root inspection and NUL-delimited status parsing.
- Added branch/upstream/ahead/behind, conflicts, recent commits, remotes, bounded output, command timeouts, safe path handling, snapshot-guarded stage/unstage, and recovery-patch-first tracked discard.
- Added real temporary-repository tests, including filenames with spaces, stale state, traversal, and untracked-file preservation.
- Network Git, force/history rewriting, credentials, and automatic conflict resolution remain outside the release boundary.
- Commit skipped because the repository contained pre-existing owner changes.

### Phase 8 ledger

**Status: complete — 2026-07-22.**

- Added a deterministic local search index with ranking, type filters, bounded results, typed references, and exact resolution.
- Added a responsive Unified Search screen over registered workspace and API metadata plus dashboard/command discovery.
- Defined workspace, file, API collection/request, OpenAPI, and Git reference schemes and unit coverage.
- Deep in-document incremental indexing remains future performance work.
- Commit skipped because the repository contained pre-existing owner changes.

### Phase 9 ledger

**Status: complete — 2026-07-22.**

- Added disabled-by-default AI provider contracts, explicit disclosure scopes, secret-aware request preparation, versioned change proposals, and confirmation gates.
- Added opt-in MCP server/tool contracts with read/write/external access declarations and per-call confirmation for side effects.
- Added policy tests proving disabled providers/servers cannot execute and writes cannot run silently.
- No provider or MCP transport is bundled or advertised as active.
- Commit skipped because the repository contained pre-existing owner changes.

### Phase 10 ledger

**Status: complete — 2026-07-22.**

- `flutter analyze` passed with no issues.
- Full `flutter test --reporter compact` passed: 384 tests.
- `flutter build windows --release` passed and produced `build/windows/x64/runner/Release/devdesk.exe`.
- `flutter build apk --debug` passed and produced `build/app/outputs/flutter-apk/app-debug.apk`.
- New tests cover API structured bodies, OpenAPI, guarded Git, unified search, AI/MCP policy, and OpenAPI compact/desktop responsiveness.
- Physical Android, signed Android release, signed Windows distribution, and clean-VM installation remain publisher gates.
- Commit skipped because the repository contained pre-existing owner changes.

### Phase 11 ledger

**Status: complete — 2026-07-22.**

- Added architecture, Markdown, OKF, API client, OpenAPI, Git, security/privacy, platform, AI/MCP, and testing/release documentation.
- Updated the README product boundary and release status.
- Reconciled the phase plan, known limitations, free-now/future-subscription posture, and external release blockers.
- Generated the final changed/new-file source ZIP with a manifest after verification.
- Commit skipped because the repository contained pre-existing owner changes.

## 20. Executed Phase 2 implementation order

Phase 2 used the following smallest safe vertical slice:

1. typed workspace/root/capability and health models;
2. workspace registry repository with additive schema migration;
3. platform filesystem contract and current safe-file adapter;
4. create/import/open/remove-metadata use cases and tests;
5. typed failures and structured privacy-safe events;
6. adaptive shell and workspace dashboard wired only to implemented actions;
7. regression, analyzer and phase ledger update.

This order establishes user-owned workspace identity and data safety before later knowledge, OKF, API, OpenAPI, Git, search or AI features depend on it.
