# Implementation Roadmap

This is an incremental remediation plan, not authorization to implement. Keep each phase independently reviewable and avoid coupling dependency, storage, UI, and release changes into one migration.

## Phase 0: Repository and release baseline

- **Objective:** Create one truthful, reproducible baseline and scope the first release.
- **Exact tasks:** Freeze supported targets; remove/disable unimplemented Diff claims; reconcile README/changelog/privacy/release files; decide `.artifacts` retention; add CI commands and artifact manifest; record coverage/build hashes; add `LICENSE`, notices, support/security contacts; open issue register owners.
- **Files likely affected:** README/PRIVACY/CHANGELOG/release docs, `.gitignore`, `.artifacts`, CI workflows, LICENSE/NOTICE.
- **Dependencies:** None.
- **Risks:** Accidentally presenting “buildable” as “supported”; deleting useful provenance without archiving.
- **Tests:** Existing format/analyze/test/build suite; documentation link/claim review.
- **Definition of done:** Clean tagged baseline, exact release scope, all report IDs tracked, truthful docs, reproducible green commands, no production behavior change.

## Phase 1: Build and dependency stabilization

- **Objective:** Make upgrades safe and replace unsupported foundations in controlled changes.
- **Exact tasks:** Add dependency policy/SBOM; create Markdown render/network fixtures; create HTTP stream/cancel fakes; design archive resource policy; migrate archive/Markdown/http/UUID/tooling in report 02 order; defer Riverpod 3 until lifecycle coverage; document Hive decision.
- **Files likely affected:** `pubspec.yaml/lock`, Markdown widgets, API executor, archive services, tests, CI.
- **Dependencies:** Phase 0; test scaffolding from Phase 10 may be pulled forward.
- **Risks:** Renderer visual/remote-resource changes, HTTP semantics, archive breaking API.
- **Tests:** All existing plus renderer goldens, malicious ZIP, every HTTP method/body/stream/cancel, all builds.
- **Definition of done:** No discontinued runtime dependency, dependency diffs reviewed, SBOM/current advisories checked, no regression across primary targets.

## Phase 2: Secret and privacy protection

- **Objective:** Close DD-SEC-001/DD-API-003 and make claims accurate.
- **Exact tasks:** Data-flow/secret inventory; classify all request/response/workspace/history/report/snippet/clipboard/export/backup sinks; design platform vault and secret references; masked reveal/copy; migrate or securely discard legacy secrets; default-exclude export; rewrite policy/Data Safety/in-product warnings.
- **Files likely affected:** API models/storage/providers/pages, LocalStorage, settings/backup, platform key-store services, privacy docs.
- **Dependencies:** Phase 0; key-management decision.
- **Risks:** Unrecoverable keys, migration data loss, web capability differences, false redaction confidence.
- **Tests:** Canary secret matrix, restart/migration/reset/export/import/clipboard/error tests on Android/Windows/web limitations.
- **Definition of done:** No canary outside approved sink, documented threat model/recovery, accurate privacy text, independent security review.

## Phase 3: Storage and migration safety

- **Objective:** Add schema lifecycle, startup recovery, and consistent clear behavior.
- **Exact tasks:** Storage bootstrap result/recovery shell; authoritative box/schema registry; validators/migrators/journal; backup-before-migration; record quarantine; disk-full/interruption faults; multi-instance decision; coordinated provider invalidation on clear.
- **Files likely affected:** `main.dart`, app bootstrap, `local_storage.dart`, all persisted models/providers, recovery UI/tests.
- **Dependencies:** Phase 2 secret model.
- **Risks:** Migration mistakes and cross-version rollback incompatibility.
- **Tests:** Old/future/corrupt/null/invalid enum records, interrupted migration, permissions, disk full, multiple Windows instances, clear during writes.
- **Definition of done:** App always reaches normal or safe recovery UI; migrations are versioned/reversible; clear is immediately and durably complete.

## Phase 4: External-file reliability

- **Objective:** Make read/save/overwrite behavior non-destructive and platform-explicit.
- **Exact tasks:** Carry encoding/BOM/line endings/target identity; binary sniff; writable preflight; temp/flush/close/atomic replace; recovery fallback; symlink/reparse/network/read-only/lock policy; lifecycle drafts; sanitize/redact errors.
- **Files likely affected:** `lib/core/files/*`, Markdown/text/JSON pages, platform services/tests.
- **Dependencies:** Phase 3 recovery primitives.
- **Risks:** Cross-filesystem atomicity and Android URI limitations.
- **Tests:** Encoding/path matrix, kill/fault injection at every save phase, native Windows/Android picker integration.
- **Definition of done:** Original remains intact on every injected failure; conversions are explicit; platform limitations documented.

## Phase 5: Backup/import transactional safety

- **Objective:** Make backup a reliable recovery mechanism.
- **Exact tasks:** Single section registry; strict type/version/app/schema metadata; full validation and limits; secret manifest/default exclusion; dry-run conflicts; staging; rollback snapshot/import journal; atomic/logical commit; recovery on startup; verify after apply.
- **Files likely affected:** `backup_utils.dart`, `local_storage.dart`, settings backup UI, every section serializer, tests.
- **Dependencies:** Phases 2–3; Phase 4 safe file output.
- **Risks:** Large memory use, legacy compatibility, rollback consuming disk.
- **Tests:** Every case in reports 05/13 with fault after each mutation; repeat merge; exit/restart during apply.
- **Definition of done:** Invalid input causes zero mutation; any injected failure restores exact pre-import state; current/legacy policy is documented.

## Phase 6: API tester reliability

- **Objective:** Make each displayed request/result trustworthy.
- **Exact tasks:** Unified prepared request bytes; correct form/multipart; bounded streaming/binary/save; connect/read/total timeouts; operation IDs/cancel/dispose; terminal collection cancel; stale-result guard; history retention; safe errors; native/web network guidance.
- **Files likely affected:** API providers/executor/models/pages/storage/snippets/tests.
- **Dependencies:** Phases 2–5; HTTP migration test base.
- **Risks:** Behavior changes for redirects/encoding/cancellation and accidental non-idempotent requests during tests.
- **Tests:** Deterministic fake streams, all methods/body types, redirects/compression, DNS/TLS/offline, cancel phases, repeated Send, out-of-order completion, close/dispose, native/web matrix.
- **Definition of done:** No request after cancel, no stale result, hard memory/time bounds, exact wire-byte tests, correct redacted persistence.

## Phase 7: Large-input performance

- **Objective:** Bound and keep responsive every untrusted-data tool.
- **Exact tasks:** Resource-policy matrix; instrumentation; caps; worker isolates for demonstrated JSON/regex/diff/archive workloads; Markdown debounce; virtualized JSON/diff/history; incremental backlinks; progress/cancel.
- **Files likely affected:** JSON/regex/diff/Markdown/vault/API/archive utilities and UI.
- **Dependencies:** Stable behavior from prior phases.
- **Risks:** Worker serialization cost, changed output, excessive arbitrary limits.
- **Tests:** Corpus/benchmarks from report 09 on low-end Android and baseline Windows.
- **Definition of done:** Published limits, acceptable p95/jank/RSS/cancel targets, graceful rejection/truncation, no lost edits.

## Phase 8: Error handling and diagnostics

- **Objective:** Replace raw/unhandled errors with recoverable, secret-safe states.
- **Exact tasks:** Domain error taxonomy; redacted user messages; local opt-in diagnostic details; AsyncValue error/retry; operation IDs; no raw tokens/paths/bodies; support bundle manifest without content by default.
- **Files likely affected:** Core errors/widgets, providers, pages, logging policy/docs.
- **Dependencies:** Secret classification and operation lifecycles.
- **Risks:** Hiding actionable detail or leaking detail through diagnostics.
- **Tests:** Error snapshot/redaction matrix and retry/state transitions.
- **Definition of done:** Every async feature has loading/success/empty/error/retry/cancel states and zero canary leakage.

## Phase 9: Responsive desktop and accessibility

- **Objective:** Deliver keyboard-first, assistive-technology-tested Android/Windows UX.
- **Exact tasks:** Command registry/palette; core shortcuts; focus order/indicators; window-close dirty handling; semantics/live announcements; accessible diff/tree; text-scale/high-contrast fixes; remove broken affordances; branding.
- **Files likely affected:** App shell/router/dashboard/shared widgets/all primary pages/Windows runner metadata.
- **Dependencies:** Stable action/state contracts.
- **Risks:** Shortcut/browser/text-field conflicts and large-text layout regressions.
- **Tests:** Semantics/widget tests, keyboard-only scripts, TalkBack/NVDA, 200% text, contrast, resize matrix.
- **Definition of done:** Every primary flow is keyboard and screen-reader operable with documented shortcuts and no critical overflow.

## Phase 10: Test expansion

- **Objective:** Turn every P0/P1 defect into a durable regression test.
- **Exact tasks:** Isolated Hive fixtures; filesystem fault layer; fake streamed HTTP; malicious archive/input corpus; platform integration harness; random-order/parallel checks; coverage risk dashboard; performance baselines.
- **Files likely affected:** `test`, new `integration_test`, test utilities/fixtures, CI.
- **Dependencies:** Interfaces introduced in phases 2–9; test scaffolding can be built earlier.
- **Risks:** Brittle platform tests and false confidence from mocks.
- **Tests:** This phase is the test program; include all required cases in reports 04/05/13.
- **Definition of done:** Each P0/P1 has a failing-before/passing-after test; green clean CI plus recorded manual exceptions; thresholds are risk-based.

## Phase 11: Android release configuration

- **Objective:** Produce a verifiable store-ready Android candidate.
- **Exact tasks:** Production signing/Play signing; fail-closed config; app identity/version; backup/data extraction rules; network behavior; icon/splash; privacy/Data Safety/content rating; screenshots/feature graphic; symbols/obfuscation decision; internal-track install/upgrade/rollback.
- **Files likely affected:** Gradle/manifests/resources/pubspec/release scripts/store dossier.
- **Dependencies:** All P0/P1 product fixes and Phase 10.
- **Risks:** Signing key loss, wrong Data Safety answers, update incompatibility.
- **Tests:** Release APK/AAB signer/manifest inspection, clean install/upgrade, Android 24/current, phone/tablet, picker/network/offline/lifecycle.
- **Definition of done:** Signed internal-track RC from clean tag with complete listing/privacy/support evidence and rollback rehearsal.

## Phase 12: Windows release configuration

- **Objective:** Produce a complete signed Windows distribution.
- **Exact tasks:** Choose installer/portable format; correct metadata/icon/version; bundle inventory/runtime prerequisites; Authenticode; install/update/uninstall/data retention; shortcuts/file associations decision; hashes; SmartScreen/support/rollback docs.
- **Files likely affected:** Windows runner/resources, packaging/signing scripts, release docs.
- **Dependencies:** Product fixes, Phase 9–10.
- **Risks:** Certificate reputation/cost, missing DLL/plugin, user-data deletion on uninstall.
- **Tests:** Fresh supported VMs/users/paths, offline, picker/overwrite/locks, network/TLS, update/rollback/uninstall, signature/hash.
- **Definition of done:** Signed package/ZIP installs and runs all core flows on the support matrix; manifest/hash and rollback are published.

## Phase 13: Final regression and release candidate

- **Objective:** Independently decide go/no-go from evidence.
- **Exact tasks:** Freeze dependencies; full CI/manual/security/privacy/accessibility/performance regression; issue audit; SBOM/license/advisory check; signed artifacts/hashes; store drafts; release notes/tag; rollback/incident drill.
- **Files likely affected:** Version/changelog/release manifests only unless defects reopen code.
- **Dependencies:** All prior release-required phases.
- **Risks:** Late fixes invalidate evidence or signatures.
- **Tests:** Full report 12 checklist and report 13 manual matrix on final signed bits.
- **Definition of done:** Zero open P0/P1, accepted P2 documented, all claims match final artifacts, independent sign-off, reproducible hashes, rollback ready.

## Recommended first implementation phase

Start with **Phase 0**, then address Phase 2 and Phase 5 P0 design work before feature additions. Phase 1's test scaffolding can run alongside design, but dependency upgrades must not precede the regression boundaries they need.
