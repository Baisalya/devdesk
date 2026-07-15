# Pre-Release Blockers and Issue Register

**Open totals:** 3 P0, 14 P1, 12 P2, 8 P3.  
P0 and P1 issues must be closed with evidence before a public release candidate. P2 requires closure or an explicit, documented risk acceptance with user-facing limitations.

## P0 — Release blockers

| ID | Finding | Status | Primary report |
| --- | --- | --- | --- |
| DD-REL-001 | Android release APK/AAB use debug signing | Confirmed | This report / 02 |
| DD-SEC-001 | API secrets persist/export without a reliable protected boundary | Confirmed | 04 / 06 |
| DD-BACKUP-001 | Backup import can clear or half-update local data without rollback | Confirmed | 05 |

### DD-REL-001: Android release artifacts use the debug signing identity

- Severity: P0
- Category: Release security
- Status: Confirmed
- Platforms: Android
- Evidence:
  - `android/app/build.gradle.kts:30-34`
  - `signingConfig = signingConfigs.getByName("debug")`
  - Release APK signer inspection confirmed the Android Debug certificate
- Current behaviour: Both release APK and AAB build successfully while the release build type explicitly uses debug signing.
- Expected behaviour: Protected upload/release key configuration outside source control, CI secret handling, signed artifact verification, rotation/recovery plan, and store Play App Signing decision.
- User impact: The artifact does not establish a trustworthy production publisher/update chain.
- Security or business impact: Release spoofing/update incompatibility, key-control failure, and store rejection or an unrecoverable production signing mistake.
- Root cause: Flutter template convenience configuration was never replaced by release signing.
- Recommended fix: Create a production signing runbook; load secrets from protected CI/local properties; fail release builds when absent; enroll/decide Play App Signing; record certificate fingerprints securely; never commit keystore/passwords.
- Verification steps: Build clean APK/AAB in release CI, verify signer/certificate lineage, install/upgrade/rollback test, inspect manifest/debuggable flags, upload to internal track, and reproduce from tagged source.
- Estimated complexity: Medium

## P1 — Must fix before release

| ID | Finding | Status | Primary report |
| --- | --- | --- | --- |
| DD-API-001 | Timeout stops at headers; response is unbounded | Confirmed | 04 |
| DD-API-002 | Cancellation/concurrency can publish stale state or continue runs | Confirmed | 04 |
| DD-API-003 | Secret redaction misses URL/body/response/snippet sinks | Confirmed | 04 |
| DD-API-004 | URL-encoded form/multipart behavior does not match UI claims | Confirmed/targeted confirmation | 04 |
| DD-STORAGE-001 | No schema migration, corruption quarantine, or startup recovery | Confirmed | 05 |
| DD-FILE-001 | External overwrite is non-atomic | Confirmed | 05 |
| DD-SEC-002 | Archive decode enforces expanded limits too late | Confirmed | 06 |
| DD-PERF-001 | Unbounded main-isolate/network work can freeze or exhaust app | Confirmed risk | 09 |
| DD-PRIV-001 | Privacy/offline claims contradict network and persistence behavior | Confirmed | 06 |
| DD-ARCH-001 | Diff and documentation advertise unavailable/no-op behavior | Confirmed | This report / 03 |
| DD-DEP-001 | Discontinued Markdown and old core package lines lack migration safety | Confirmed | This report / 02 |
| DD-TEST-001 | Release-critical paths have little/no meaningful coverage | Confirmed | This report / 02 |
| DD-REL-002 | Windows has no verified signed installer/portable distribution | Confirmed | This report / 08 |
| DD-REL-003 | Store/legal/support/release operations are incomplete | Confirmed | This report / 12 |

### DD-ARCH-001: Prominent Diff and documentation behavior is missing or unreachable

- Severity: P1
- Category: Architecture/Product correctness
- Status: Confirmed
- Platforms: All
- Evidence:
  - `lib/features/diff_checker/presentation/diff_page.dart:274,336-365,470`
  - `.artifacts/*/walkthrough.artifact.md`
  - `README.md`, `CHANGELOG.md`, `final_report_table.md`
- Current behaviour: UI promises files/ZIPs, GitHub, Git, export, and history, while ZIP services are unwired, Git only probes availability, root GitHub URLs cannot fetch content, export is a snackbar, and history is memory-only. Tracked generated walkthrough/release prose overstates completion/testing.
- Expected behaviour: Every visible action completes a safe flow with tests, or is removed/clearly marked unavailable; documentation reflects code and verified behavior.
- User impact: Users waste time, lose expected output, and cannot trust the product description.
- Security or business impact: Misrepresentation and unnecessary GitHub/archive attack surface.
- Root cause: Service/UI scaffolding and generated claims were treated as completed functionality.
- Recommended fix: Choose a narrow release scope: retain verified text diff and remove/disable claims, or complete file/ZIP/GitHub/export with bounds/cancellation/tests. Remove generated audit artifacts from release claims.
- Verification steps: Trace every Diff button to observable output; two files, ZIPs, repo/blob URLs, offline/error/cancel/export/restart; reconcile README/changelog/store listing.
- Estimated complexity: Medium if scoped down; Large if completed

### DD-DEP-001: Core dependency modernization lacks a tested migration path

- Severity: P1
- Category: Dependencies/Maintainability
- Status: Confirmed
- Platforms: All
- Evidence:
  - `pubspec.yaml:12-20`
  - `flutter pub outdated` reported 28 incompatible updates
  - `flutter_markdown` 0.6.23 is discontinued
- Current behaviour: The project builds, but Markdown is on a discontinued package and HTTP/Riverpod/UUID/archive are behind current major lines. High-risk behavior lacks tests needed to upgrade safely.
- Expected behaviour: Maintained renderer with explicit resource policy and staged, test-backed upgrades—not one bulk upgrade.
- User impact: Compatibility/security fixes become harder and future Flutter upgrades may break unexpectedly.
- Security or business impact: Dependency maintenance and untrusted-content risk, with increasing migration cost.
- Root cause: Feature delivery outpaced dependency/test stewardship.
- Recommended fix: Follow report 02's order: baseline → archive policy/migration → Markdown replacement → bounded HTTP executor/http 1.x → UUID/tooling → Hive decision → Riverpod 3.
- Verification steps: Lockfile diff review, official changelogs, all tests/builds, renderer goldens/network policy, executor streaming/cancel tests, provider lifecycle tests.
- Estimated complexity: Large across phases

### DD-TEST-001: Highest-risk release behaviors are not protected by tests

- Severity: P1
- Category: Testing
- Status: Confirmed
- Platforms: All
- Evidence:
  - 47.95% overall line coverage
  - 0% external-file service; 5.1% workspace executor; 8.1% workspace provider; 0.4% Diff page
  - No integration-test target/native manual evidence
- Current behaviour: 135 tests pass, but startup failure/corruption, read timeout, cancellation, response limits, secret sinks, rollback, atomic save, regex bomb, huge JSON, OS close, native pickers, CORS, and accessibility are absent.
- Expected behaviour: Risk-weighted unit/component/integration/platform tests that fail for each P0/P1 defect and run in release CI.
- User impact: Severe regressions can ship despite a green suite.
- Security or business impact: False release confidence and unsafe dependency/storage migrations.
- Root cause: Coverage concentrated on utilities/rendering and happy paths.
- Recommended fix: Add deterministic fakes/fault injection, temporary isolated Hive directories, malicious fixtures, integration tests, and manual platform evidence. Do not optimize for coverage percentage alone.
- Verification steps: Demonstrate each regression test fails on old behavior and passes on fix; parallel/random order; leaked handles/temp files; CI artifact/report retention.
- Estimated complexity: Large

### DD-REL-002: Windows distribution is neither packaged nor publisher-signed

- Severity: P1
- Category: Release
- Status: Confirmed
- Platforms: Windows
- Evidence:
  - `flutter build windows` passes
  - `windows/runner/Runner.rc:92-98` retains lowercase generic metadata
  - No installer/portable manifest, code-signing, upgrade/uninstall, or distribution runbook
- Current behaviour: A build directory is produced; the executable alone is only the runner and depends on adjacent data/plugins. No verified package preserves the full runtime or establishes publisher identity.
- Expected behaviour: Signed installer or verified portable ZIP with all dependencies, version/branding, install/uninstall/upgrade/rollback behavior, hashes, and SmartScreen strategy.
- User impact: Broken copies, warnings, uncertain updates, and inconsistent local-data retention.
- Security or business impact: Supply-chain/publisher trust and support risk.
- Root cause: Build success was conflated with distributable product.
- Recommended fix: Select MSIX/MSI/Inno/WiX or documented portable ZIP; sign executable/package; inventory files; test clean install/update/uninstall and data preservation/removal; publish SHA-256.
- Verification steps: Fresh supported Windows VMs, standard/non-admin user, paths with Unicode/spaces, offline launch, file dialogs, firewall/TLS, upgrade/rollback, uninstall, signature/hash verification.
- Estimated complexity: Medium/Large

### DD-REL-003: Legal, store, support, and release operations are incomplete

- Severity: P1
- Category: Release governance
- Status: Confirmed
- Platforms: Android/Windows/Web
- Evidence:
  - README claims MIT but no `LICENSE` file exists
  - No third-party notices, privacy URL/store artifacts, support contact, release runbook, tag/rollback plan, or verified screenshots
  - `RELEASE_CHECKLIST.md` is stale/incomplete
- Current behaviour: Version `1.0.0+1` can be built, but essential distribution metadata and operational controls are missing or contradictory.
- Expected behaviour: License/notice compliance, accurate policy URL/Data Safety/content rating, support/security contact, asset set, reproducible commands, signed hashes/symbol policy, tagged release notes, rollback and incident process.
- User impact: Missing trust/support information and inconsistent product identity.
- Security or business impact: Store rejection, license/compliance exposure, inability to respond safely to a bad release.
- Root cause: Engineering artifacts exist without a complete release owner/checklist.
- Recommended fix: Establish an accountable release dossier and block publishing until every applicable checkbox in report 12 has evidence.
- Verification steps: Independent release review from clean tag/runner, store draft validation, license scan, support/security contact test, artifact signature/hash, install/update/rollback rehearsal.
- Estimated complexity: Medium

## P2 — Strongly recommended

| ID | Finding | Status | Evidence/report |
| --- | --- | --- | --- |
| DD-ARCH-002 | Presentation directly owns storage/files/HTTP/platform calls | Confirmed | 01 |
| DD-API-005 | Cleartext/web/CORS/localhost/TLS limitations lack coherent UX | Confirmed | 04 |
| DD-FILE-002 | Encoding/BOM/line-ending/target identity policy is incomplete | Confirmed | 05 |
| DD-BACKUP-002 | Backup version/app metadata/preview registry incomplete | Confirmed | 05 |
| DD-UI-001 | Desktop keyboard/command model is missing | Confirmed | 08 |
| DD-A11Y-001 | Semantics/screen readers/text scale/high contrast unverified | Needs runtime verification | 08 |
| DD-PERF-002 | Histories/reports/vault/snippets grow without scalable retention | Confirmed | 09 |
| DD-PRIV-002 | Markdown remote-resource network behavior lacks explicit policy | Needs runtime verification | 06 |
| DD-BUILD-001 | Web metadata/behavior is generic and not support-validated | Confirmed | 02/08 |
| DD-REL-004 | App identity/version/support/license metadata is inconsistent | Confirmed | 00/08 |
| DD-STORAGE-002 | Clear Data does not coordinate live provider state | Confirmed | 05 |
| DD-ARCH-003 | Tracked `.artifacts` contain generated/stale overclaims | Confirmed | 01/03 |

## P3 — Future improvement

| ID | Finding/opportunity | Status |
| --- | --- | --- |
| DD-UI-002 | “DevKit Offline” and lowercase platform branding should become consistent DevDesk identity | Confirmed |
| DD-API-006 | cURL first, then selected cookies/chaining/GraphQL/realtime capabilities | Product opportunity |
| DD-FILE-003 | Draft recovery and OS/window-close protection | Product opportunity |
| DD-PERF-003 | Instrumented debounce/incremental Markdown rendering | Product opportunity |
| DD-TEST-002 | Broader platform/version/device matrix and performance regression lab | Product opportunity |
| DD-REL-005 | Evaluate iOS/macOS/Linux only after build and core-flow verification | Deferred |
| DD-DEP-002 | Decide long-term Hive/storage engine strategy from migration needs, not novelty | Strategic |
| DD-ARCH-004 | Plugin architecture only after trust model and stable core commands | Deferred |

## Release gate

Public release is blocked until all three P0 and fourteen P1 issues are closed with code-review, automated-test, manual-platform, documentation, and signed-artifact evidence. Build success alone cannot close an issue.
