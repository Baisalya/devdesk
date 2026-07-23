# DevDesk Architecture

## Product boundary

DevDesk is a local-first Flutter developer workspace for Android and Windows. User-selected files remain canonical. Hive stores application metadata, indexes, drafts, API workspaces, and recovery state; it does not replace workspace source files.

## Layers

- `lib/app` owns startup, command discovery, navigation, theme, privacy acceptance, and global shortcuts.
- `lib/core` owns typed failures, storage migrations, redaction, bounded networking, safe file replacement, platform channels, and shared UI.
- `lib/features/*/domain` contains immutable models and service contracts.
- `lib/features/*/data` implements local persistence, parsing, filesystem, or process boundaries.
- `lib/features/*/provider` coordinates use cases through Riverpod.
- `lib/features/*/presentation` contains adaptive Material 3 screens.

Dependencies point inward: presentation may depend on providers and domain models; providers depend on contracts; adapters implement those contracts. Widgets do not directly invoke Git, parse OpenAPI, or write workspace files.

## Workspace data flow

1. The user grants a folder or document-tree capability.
2. The registry saves opaque root metadata and platform capabilities.
3. A bounded indexer enumerates supported content while excluding `.git`, build caches, and symlinks by default.
4. Domain parsers build Markdown, OKF, API, OpenAPI, Git, and search views.
5. Drafts and indexes remain internal metadata. A source-file write requires the workspace write capability and the expected source fingerprint.
6. Windows file replacement uses the existing verified atomic-replacement boundary. Android document-tree writes remain unavailable until a persisted SAF adapter exists.

## Persistence and migrations

Storage schema 3 adds workspace registry, metadata, indexes, and activity boxes. Migration is additive and journaled by `LocalStorage`; legacy boxes remain intact. Backup import is previewed and transactional, with rollback recovery. API secret values use the platform protected store rather than ordinary portable records.

## Extension boundaries

- Unified search consumes typed `SearchRecord` values; it does not know feature storage details.
- Cross-feature links use explicit schemes such as `workspace:`, `file:`, `api-request:`, and `openapi:`.
- AI is disabled by default. Provider configuration, disclosure scope, secret redaction, and reviewable proposals are separate concerns.
- MCP servers are opt-in. Tool access is declared as read-only, workspace-writing, or externally side-effecting; the latter two require per-call confirmation.

## Reliability invariants

- No shell interpolation for Git commands.
- Network responses, subprocess output, file reads, and index sizes are bounded.
- Unknown OKF fields are preserved and accepted.
- OpenAPI source remains canonical; generated collections and Markdown carry source references.
- Metadata removal never deletes a workspace folder.
- Unsupported capabilities fail visibly and never report success.

See `FUTURISTIC_DEVELOPER_WORKSPACE_IMPLEMENTATION_PLAN.md` for the audit, phase ledgers, decisions, and remaining risks.
