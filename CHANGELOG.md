# Changelog

This project follows Keep a Changelog conventions. No entry is a claim that an artifact was signed, store-approved, or manually verified unless the entry says so explicitly.

## [1.0.1] - Unreleased

### Security

- Separated API workspace secrets from ordinary Hive records using an Android Keystore/Windows DPAPI protected overlay; web persistence is disabled for secrets.
- Added centralized redaction for URLs, headers, cookies, JSON/text bodies, responses, errors, histories, reports, snippets, collection exports, backups, and clipboard actions.
- Added pre-decompression ZIP central-directory and local-header validation with traversal, duplicate, encryption, symbolic-link, depth, count, expanded-size, per-entry, and compression-ratio limits.
- Blocked remote Markdown images.
- Made Android release builds fail closed when real production signing configuration is absent.

### Reliability

- Reworked backup import to validate and stage before mutation, persist a rollback journal, verify the imported state, and restore exact snapshots after failure or interrupted startup.
- Added storage schema/version metadata, migration journaling, startup recovery UI, record quarantine support, and destructive reset.
- Replaced direct external-file truncation with guarded staging and atomic replacement where supported; added encoding/BOM/line-ending preservation and file identity checks.
- Added bounded streamed HTTP response handling, connection/read-idle/total deadlines, binary previews, cancellation, duplicate-send suppression, operation identity, and disposal guards.
- Added bounded JSON, regex, diff, GitHub, archive, folder, history, report, and external-file operations.

### Accessibility and desktop

- Added a command registry and command palette, desktop editor shortcuts, dirty-window close protection, visible loading/error announcements, and screen-reader alternatives for JSON tree and diff output.
- Corrected Windows product metadata and added portable distribution/signing tooling.

### Dependencies

- Replaced discontinued `flutter_markdown` with `flutter_markdown_plus`.
- Staged HTTP 1.x and UUID 4.x migrations after adding focused tests.
- Deferred archive 4.x and Riverpod 3.x major migrations until the full SDK verification matrix is available.

### Documentation

- Rewrote offline/privacy claims to describe user-initiated network activity and platform limitations accurately.
- Added signing, packaging, support, security, store metadata, rollback, threat-model, verification, and remediation evidence documents.

## [1.0.0] - 2026-06-19

Initial development baseline. This version is retained for history and is not represented as a verified public release candidate.
