# Release Remediation Evidence Matrix

**Workspace:** uncommitted remediation working tree on `master`  
**Audit baseline:** source snapshot corresponding to audit commit `098eb08`  
**Status date:** 15 July 2026

`Verified` below means the implementation passed the applicable automated test
and build gates in this workspace. It does not replace signed-artifact,
real-device, clean-VM, accessibility, or performance evidence.

| Issue | Implementation evidence | Test/evidence status | Release status |
| --- | --- | --- | --- |
| DD-REL-001 | Fail-closed Gradle release signing, external properties/env configuration, signing runbook | Unsigned release command rejected as designed; real keystore unavailable | Verified configuration, externally blocked |
| DD-SEC-001 | Android Keystore/Windows DPAPI secret overlay; ordinary workspaces sanitized; web session-only | Overlay, migration, stale-copy, restored-header, and export canary tests pass; native code compiles | Verified automated behavior; native lifecycle test pending |
| DD-BACKUP-001 | Full validation/staging, snapshots, persistent journal, rollback and verification | Future-version, partial failure, interrupted recovery, type-safe rollback, and limits tests pass | Verified automated behavior |
| DD-API-001 | Bounded streamed reader, declared/actual byte limits, binary preview, connect/idle/total deadlines | Delayed, stalled, oversized, and binary tests pass | Verified automated behavior |
| DD-API-002 | Operation identity, cancellation token, client close, duplicate-send suppression, disposal guards | Duplicate, out-of-order, cancellation, and disposal tests pass | Verified automated behavior |
| DD-API-003 | Central deep/text/URL/header/error redaction and common clipboard boundary | Canary tests across requests, responses, history, protected overlays, and sinks pass | Verified automated behavior |
| DD-API-004 | One prepared-request model; JSON/text/empty/form/multipart text-field handling | Wire-behavior and invalid-input tests pass | Verified automated behavior |
| DD-STORAGE-001 | Schema version, migration journal, recovery UI, future-version rejection, record quarantine hook | Startup failure, migration interruption, future schema, and damaged workspace tests pass | Verified automated behavior |
| DD-FILE-001 | Temp write/flush/close, identity revalidation, native Windows atomic replace, fallback-safe Save As | Failure preservation, BOM/EOL, rename, and symlink tests pass; Windows native build passes | Verified automated behavior; native manual test pending |
| DD-SEC-002 | ZIP central/local header checks before decode and strict limits; archive 4.0.9 | Traversal, ratio, mismatch, overlap, byte-limit, and vault round-trip tests pass | Verified automated behavior |
| DD-PERF-001 | JSON/regex/diff/archive/network/file/folder/history/report limits; diff worker/debounce identities | Huge/deep/catastrophic/oversized tests pass | Verified automated behavior; device profiling pending |
| DD-PRIV-001 | Privacy/README/store copy rewritten to disclose user-initiated network and platform differences | Documentation/code review | Implemented, public URL owner input pending |
| DD-ARCH-001 | Release scope narrowed; no-op/overstated artifacts removed; diff export/history bounded and honest | Full widget/unit suite passes | Verified automated behavior |
| DD-DEP-001 | Markdown continuation, Dart floor, HTTP 1.6, UUID 4.6, archive 4.0.9 | Lockfile resolved; outdated and dependency scans executed; all builds pass | Verified current migration; later major upgrades remain |
| DD-TEST-001 | Risk-weighted unit/widget/fault/malicious stream/archive/storage/file tests added | 184 tests pass; 52.86% line coverage | Verified |
| DD-REL-002 | Correct metadata; complete portable packaging/inventory/hash/signing hook and runbook | Windows release build and unsigned package extraction/hash verification pass | Verified unsigned flow; certificate/clean VM blocked |
| DD-REL-003 | MIT license, privacy/security/support, store draft, notices generator, release/rollback runbooks | Public URLs/contact/store assets require owner | Partially implemented, owner inputs pending |

## Related P2 addressed

Command palette and desktop shortcuts, dirty-window close handling, JSON/diff screen-reader alternatives, live status regions, remote Markdown resource blocking, encoding/BOM/line-ending preservation, web metadata, Android backup/network rules, and bounded retention were addressed where they shared modified architecture.

## Release decision

**HOLD for public release.** Dependency resolution, formatting, analysis, 184
tests/coverage, and Android debug, Windows release, and web release builds pass.
Public release still requires supported-device manual accessibility/performance
tests, real Android signing, signed Windows portable verification on a clean VM,
owner metadata/URLs/assets, and independent go/no-go approval.
