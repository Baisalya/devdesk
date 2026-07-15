# Storage, External Files, and Backup Audit

## Hive inventory

| Box | Stored data | Format/version | Clear data | Backup | Sensitivity |
| --- | --- | --- | --- | --- | --- |
| `settings` | Theme and settings values | Dynamic keys; no schema | Yes | Yes | Low/medium |
| `dashboard` | Favorites and recent routes | Lists; no schema | Yes | Yes | Low |
| `api_history` | Quick API request history | Maps; no schema | Yes | Yes | High |
| `api_environments` | Quick environment values | Maps; no schema | Yes | Yes | High |
| `api_workspaces` | Workspace/collection/request/environment definitions | Nested maps; internal format markers but no migration enforcement | Yes | Yes | Critical |
| `api_workspace_history` | Requests/responses | Nested maps | Yes | Yes | Critical |
| `api_workspace_reports` | Collection-run results | Nested maps | Yes | Yes | High |
| `api_workspace_meta` | Active IDs/migration markers | Dynamic | Yes | Yes | Medium |
| `snippets` | Snippet records | Map casts; no schema | Yes | Yes | Medium/high |
| `markdown_files` | Internal Markdown text | String values | Yes | Yes | Medium/high |
| `vault_notes` | Notes, metadata, backlinks, full version history | Nested maps | Yes | Yes, but omitted from backup preview helper | High |
| `vault_metadata` | Vault metadata | Dynamic | Yes | Yes, but omitted from backup preview helper | Medium |

All boxes are opened without a Hive cipher. No account/logout boundary exists. The relevant threat model is local filesystem access, OS/user-account compromise, backups/clipboard, support sharing, malware, and lost device—not ordinary Android sandbox separation from unrelated apps. Encryption requires platform key management, recovery/reset semantics, migration of existing records, desktop key-store decisions, and tests; it should not be bolted onto every box indiscriminately.

## Storage initialization and evolution

- `LocalStorage.initialize()` runs before `runApp` (`main.dart:13-14`). Any directory/permission/corruption/open failure prevents the app from showing recovery UI.
- `_initialized` is a process-wide flag and boxes open lazily. Theme and feature notifiers start additional unguarded loads.
- Data uses primitive/nested maps rather than Hive adapters. This avoids adapter IDs but moves compatibility risk to unchecked casts/defaults inside each model.
- No central schema/app data version, preflight migration, backup-before-migration, rollback, corruption quarantine, or “open read-only/export” mode exists.
- Writes and multi-record recalculations are sequential. Disk-full/interruption can leave logically inconsistent boxes.
- No policy exists for simultaneous Windows instances or file locking. Histories, reports, snippets, and vault growth are not capped globally.

### DD-STORAGE-001: Storage has no migration, corruption, or startup recovery boundary

- Severity: P1
- Category: Storage/Reliability
- Status: Confirmed
- Platforms: All
- Evidence:
  - `lib/main.dart:13-14`
  - `lib/core/storage/local_storage.dart:40-62`
  - strict `fromMap` calls in snippets, vault, and API workspace models
- Current behaviour: Startup awaits storage before UI. Records have no coordinated schema/migration path, and invalid casts/open failures are not quarantined or recoverable in-product.
- Expected behaviour: Versioned schema, validation/migration before normal use, recoverable startup screen, read-only export/reset choices, migration backup/rollback, and corrupted-record isolation.
- User impact: One bad box/record or failed upgrade can make a feature—or the whole app—unusable with no safe recovery.
- Security or business impact: Data loss and upgrade distrust in a local-data product.
- Root cause: Storage grew feature-by-feature without an application-level lifecycle coordinator.
- Recommended fix: Add a storage bootstrap result model, schema registry, migration journal, validation, backup-before-change, per-record quarantine where feasible, and a minimal recovery shell before feature providers start.
- Verification steps: Permission denial, corrupt box/record, old/future schema, interrupted migration, disk full, missing fields, invalid enums/nulls, multi-instance Windows launch, and recovery export/reset.
- Estimated complexity: Large

### DD-STORAGE-002: Clear Data can leave live providers showing stale data

- Severity: P2
- Category: Storage/UX
- Status: Confirmed
- Platforms: All
- Evidence:
  - `lib/features/settings/presentation/settings_page.dart:211`
  - feature notifiers retain in-memory state after `LocalStorage.clearAll()`
- Current behaviour: All declared boxes are cleared, but dependent providers/controllers are not centrally invalidated or reinitialized.
- Expected behaviour: After confirmed clear, every feature immediately reflects defaults and no later stale write recreates deleted data.
- User impact: Data can appear not deleted or return after a pending provider save.
- Security or business impact: Privacy deletion promise becomes ambiguous.
- Root cause: Clear is a storage-only operation without application state coordination.
- Recommended fix: Enter a global clearing state, cancel writes/requests, clear boxes, invalidate/recreate scoped providers, verify empty boxes, and report completion/failure.
- Verification steps: Keep every feature open, begin edits/request, clear, navigate back, restart, and inspect all boxes.
- Estimated complexity: Medium

## External-file behavior

Positive controls:

- User-initiated system picker; `withReadStream: true`.
- General cumulative input cap of 5 MiB (`external_file.dart:53,143-145`).
- No Android `READ/WRITE_EXTERNAL_STORAGE` or `MANAGE_EXTERNAL_STORAGE` permission.
- Extension/content dispatch and explicit overwrite confirmation in Markdown/text pages.

Gaps:

- Strict UTF-8 only; no UTF-16, BOM stripping/preservation, invalid-byte preview, encoding selection, or line-ending preservation contract.
- “Can overwrite” is inferred from a desktop path, not actual existence/writability/read-only/lock status.
- Missing/renamed/deleted targets, symlinks/reparse points, network paths, long paths, and multiple-instance writes have no explicit policy.
- Save As delegates overwrite behavior to native dialogs and is not tested on Windows/Android.
- Error messages may include raw exception/path details. Disk-full/write interruption recovery is absent.

### DD-FILE-001: Overwrite original is a direct non-atomic write

- Severity: P1
- Category: File safety
- Status: Confirmed
- Platforms: Windows and other direct-path desktop targets
- Evidence:
  - `lib/core/files/external_file_service.dart:88-94`
  - `ExternalFileService.overwriteOriginal`
- Current behaviour: After UI confirmation, `File(document.path!).writeAsString(content)` writes directly to the original path.
- Expected behaviour: Confirm, verify target/writability/identity, write a same-filesystem temporary file, flush and close, atomically replace where supported, preserve/reapply metadata as intended, and retain a recovery artifact if replacement fails.
- User impact: A crash, disk-full event, permission change, or interruption can truncate/corrupt the only copy.
- Security or business impact: Direct user data loss in a core advertised workflow.
- Root cause: Convenience API used as the persistence transaction.
- Recommended fix: Build a platform-aware safe-replace service with explicit symlink/reparse/network-path policy and clear fallback messaging; keep Save As when atomic replace cannot be guaranteed.
- Verification steps: Read-only/locked/deleted/renamed/symlink/network/long paths, disk full, kill between write/flush/replace, same/cross-volume behavior, CRLF/BOM/encoding, and Windows Defender/file-indexer contention.
- Estimated complexity: Large

### DD-FILE-002: Text encoding and target identity are underspecified

- Severity: P2
- Category: File safety
- Status: Confirmed
- Platforms: Android/Windows
- Evidence:
  - `lib/core/files/external_file.dart`
  - `ExternalFileDetector` and `ExternalFileService`
- Current behaviour: Supported-looking files are decoded as strict UTF-8 and later saved as UTF-8 text; symlink/MIME/BOM/line-ending/identity decisions are not surfaced.
- Expected behaviour: Detect supported BOMs, reject binary safely, disclose conversions, preserve line endings where possible, revalidate target identity, and document URI/path limitations.
- User impact: Valid UTF-16 files fail; encoding or line endings can change; renamed target races can produce surprises.
- Security or business impact: Accidental data mutation and unsafe path assumptions.
- Root cause: A single cross-platform text abstraction masks platform and encoding differences.
- Recommended fix: Carry encoding/BOM/line-ending/target metadata in `ExternalFile`; add explicit conversion choices and revalidation.
- Verification steps: UTF-8/UTF-8 BOM/UTF-16 LE/BE, invalid UTF-8, binary-renamed-text, LF/CRLF, empty/5 MiB+, Android content URI, and Windows path variants.
- Estimated complexity: Medium

## Backup format and behavior

Current document shape contains `type: devdesk_backup`, `version: 1`, `exportedAt`, and `boxes`. It does not include the producing app version/build, schema versions per section, checksums, or secret manifest. `BackupUtils.extractBoxes` treats a matching type as wrapped but does not validate `version`; it also accepts a legacy raw-box map. Unknown boxes are ignored. Preview knows fewer boxes than export.

Replace mode clears and fills each box sequentially. Merge overwrites identical keys and has no record-specific duplicate/conflict policy. Neither mode takes a snapshot, validates every record, stages data, or rolls back. Applying the same merge twice is often idempotent by key but not guaranteed semantically for all future models.

### DD-BACKUP-001: Backup import can leave storage cleared or half updated

- Severity: P0
- Category: Data integrity
- Status: Confirmed
- Platforms: All
- Evidence:
  - `lib/core/storage/local_storage.dart:98-120`
  - `LocalStorage.importAll`
- Current behaviour: Import validates a shallow outer shape, then iterates boxes. Replace clears a destination box before writing it. Any later parse/write/disk failure leaves prior boxes changed and possibly the current box empty.
- Expected behaviour: Validate and materialize the entire import first, stage it separately, take a recovery snapshot, apply atomically/logically transactionally, and roll back all affected boxes on failure.
- User impact: A malformed record, disk-full condition, or interrupted import can destroy good local data.
- Security or business impact: Catastrophic loss in the feature intended to protect data.
- Root cause: Per-box Hive operations are mistaken for a multi-box transaction.
- Recommended fix: Introduce versioned validators and migration into typed staging models; compute preview/conflicts; create verified rollback snapshot; commit with an import journal and restore on any error. Block app exit or recover on next startup.
- Verification steps: Every specified valid/empty/legacy/future/malformed/truncated/huge/deep/missing/unknown/duplicate/invalid-date/invalid-enum case plus injected failure after every clear/put and process termination.
- Estimated complexity: Large

### DD-BACKUP-002: Backup compatibility and preview metadata are incomplete

- Severity: P2
- Category: Backup/Compatibility
- Status: Confirmed
- Platforms: All
- Evidence:
  - `lib/core/storage/backup_utils.dart:36-105`
  - `BackupUtils.version`, `knownBoxes`, `extractBoxes`
- Current behaviour: Version 1 is emitted but unsupported future versions are accepted; app version is absent; vault boxes are exported by `LocalStorage` but omitted from `BackupUtils.knownBoxes` preview.
- Expected behaviour: Strict type/version compatibility, producing app/build/schema metadata, included/excluded section and secret disclosure, complete preview, size/depth/count limits, and future-version refusal.
- User impact: Users cannot assess compatibility or complete contents and may import data the app cannot safely interpret.
- Security or business impact: Silent data omission/misinterpretation and accidental secret sharing.
- Root cause: Backup envelope and storage registry are duplicated and shallow.
- Recommended fix: One authoritative section registry with versioned validators/migrators, sensitivity metadata, count/size limits, and compatibility matrix.
- Verification steps: Version 0/1/future, unknown sections/fields, all boxes including vault, app-version round trips, huge/deep values, and safe preview without mutation.
- Estimated complexity: Medium

## Backup secret risk

Backup reads all values from all boxes, including API workspaces/history/environments and potentially vault/snippet content. Save-to-file and copy-to-clipboard provide no per-section or secret exclusion control. The correct near-term behavior is to exclude protected secrets by default, show a precise content/sensitivity manifest, and require explicit reauthentication/confirmation for any secret-inclusive encrypted export. A blanket statement that the file “remains under your control” is not sufficient.
