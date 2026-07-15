# Feature Completeness Audit

Legend: **Yes** = confirmed in code/tests; **Partial** = important limitations; **No** = absent/broken; **Unverified** = requires platform/runtime verification. “Offline” means the core operation does not intentionally make a network request.

| Feature | Implemented | Functional | Tested | Secure | Offline | Release-ready | Evidence |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Dashboard/search/favorites/recents | Yes | Yes | Partial | Yes | Yes | Partial | `tool_providers.dart:12-18,56-84`; dashboard widget tests |
| Open developer file | Yes | Partial | Partial | Partial | Yes | No | `dashboard_page.dart:174`; external service has 0% coverage |
| Markdown editor | Yes | Yes | Partial | Partial | Partial | No | `markdown_page.dart:118-190,367-700`; remote image behavior needs runtime verification |
| Markdown Vault | Yes | Partial | Partial | Partial | Partial | No | `vault_provider.dart`, `vault_export_service.dart:49-68` |
| README generator | Yes | Yes | Partial | Partial | Yes | Partial | `readme_page.dart:174`; generator tests |
| JSON tools | Yes | Partial | Partial | Partial | Yes | No | `json_page.dart`; `json_utils.dart`; unbounded tree/input work |
| Quick API tester | Yes | Partial | Partial | No | No | No | `api_provider.dart:285-343` |
| API workspaces/collections | Yes | Partial | Partial | No | No | No | workspace provider/executor/storage; form and secret gaps |
| JWT decoder | Yes | Yes | Partial | Partial | Yes | Partial | `jwt_page.dart:139-143`; `jwt_utils.dart:14-67` |
| Regex tester | Yes | Partial | Partial | No | Yes | No | synchronous `RegExp` matching on UI isolate |
| Base64 | Yes | Partial | Partial | Partial | Yes | Partial | `base64_utils.dart:9-18`; text-only standard Base64 |
| URL encode/decode | Yes | Partial | Partial | Partial | Yes | Partial | `url_utils.dart:6-19`; component semantics only |
| Timestamp converter | Yes | Partial | Partial | Partial | Yes | No | `timestamp_utils.dart:5-30`; digit-length heuristic |
| UUID generator | Yes | Yes | Partial | Yes | Yes | Partial | `uuid_utils.dart:5-15`; v4, 1–1000 |
| Text diff | Yes | Partial | Partial | Partial | Yes | Partial | diff utilities and basic text UI work |
| File/ZIP/Git/GitHub diff | Partial | No | No | No | Partial | No | `diff_page.dart:274,336-365,470`; export/ZIP UI stubs |
| Snippets | Yes | Partial | Partial | Partial | Yes | No | `snippets_provider.dart:7-39`; no import/export/migration |
| Settings/theme | Yes | Yes | Partial | Partial | Yes | Partial | `app.dart:31-46`; settings widget tests |
| Clear data | Yes | Partial | Partial | Partial | Yes | No | `settings_page.dart:211`; providers not invalidated |
| Backup export/import | Yes | Partial | Partial | No | Yes | No | `local_storage.dart:78-120`; no transaction/rollback |

## Dashboard

- Tool registry contains Markdown Vault/Editor, README, JSON, API Workspaces, JWT, regex, Base64, URL, timestamp, UUID, Diff, snippets, and settings.
- Search is case-insensitive after `trim()` and matches name/description. Empty-state UI exists. Responsive grid selects one to four columns.
- Favorites and recents persist to Hive. Recent route IDs are validated; favorite IDs loaded from storage are not. Async load/write failures do not produce an error/retry state.
- Open File is present. There is no global tool command palette, shortcut, or purpose-designed keyboard grid navigation.
- Header branding says “DevKit Offline,” which is inconsistent with DevDesk.

## Markdown editor and vault

- Editing, live preview, toolbar insertion, internal save, external open, Save As, confirmed external overwrite, copy, and in-app unsaved-change prompts are implemented.
- External input is strict UTF-8 and capped at 5 MiB. UTF-16/BOM and original encoding/line-ending preservation are not supported.
- Full Markdown preview is rebuilt as text changes; a multi-megabyte document can jank or freeze. In-app `PopScope` does not protect against OS termination/window close.
- `Markdown(data: ...)` has no explicit link/image policy. Remote image URLs may cause a network fetch depending on renderer/platform; confirm and document this before release. Raw HTML/link behavior also lacks explicit tests.
- Internal filename normalization exists, but saving/renaming can overwrite an existing internal note without a conflict workflow.
- Vault supports folders/tags/wiki links/backlinks, quick switcher/command palette, versions, exports, ZIP import, and URL checks. Every material change recalculates and rewrites backlinks across notes; up to 50 full-content versions live inside each note.
- ZIP decompression occurs before declared expanded-size checks (`vault_export_service.dart:50-68`), so compressed input can exhaust memory. Backup JSON emits a version but the parser does not enforce it; UI offers ZIP import only.

## README generator

- Required project-name validation, optional sections, editable generated Markdown, copy, internal/vault save, and file export are present.
- User fields are inserted into Markdown without escaping. This is sometimes desirable but can break titles/links/lists or create unintended Markdown; the UI does not explain the contract.
- Internal save can overwrite the same name without a visible conflict/compare step. No safe overwrite flow for an existing disk README is offered beyond the generic Save As dialog.

## JSON tools

- Validation, pretty formatting, minification, tree view, file input, and parse-offset line/column feedback work for ordinary JSON.
- Input parsing, re-parsing, and recursive tree materialization are synchronous. There is no text-size, node-count, nesting-depth, or render-budget limit for pasted data.
- Duplicate object keys are silently collapsed by `jsonDecode`. Web numeric precision and extreme depth are not explained. Strict external UTF-8 rejects invalid bytes, but pasted Unicode is supported.
- Huge arrays/objects and deep nesting can freeze the UI or overflow recursive rendering. The tree is not virtualized.

## JWT decoder

- Base64URL normalization/padding and JSON header/payload decode work, including Unicode claims. Expiry timestamps are displayed in UTC.
- The page correctly and visibly states: “Signature not verified” and “does not validate the signing key” (`jwt_page.dart:139-143`).
- Parsing accepts two or more segments rather than exactly three. It does not separately warn on `alg: none`, validate issuer/audience/signature, or present a “not yet valid” state for `nbf`.
- Token input and copy/paste remain visible sensitive data. There is no persistence in the decoder, but clipboard/screenshot exposure is inherent and should be disclosed.

## Regex, Base64, URL, timestamp, and UUID

- **Regex:** invalid patterns and match display work; case sensitivity and multiline flags exist. Matching is synchronous with no timeout, input/pattern limit, worker isolate, or cancellation. Catastrophic backtracking can freeze the application. Dot-all/unicode flavor controls and a regex explanation/debugger are absent.
- **Base64:** standard Base64 over UTF-8 text works and rejects malformed input. Base64URL, raw binary/file input, binary output, streaming, and large-input bounds are absent.
- **URL:** this is a component encoder/decoder (`Uri.encodeComponent`/`decodeComponent`), not a URL/query parser. Form-style plus-to-space semantics, structured query editing, and double-encoding guidance are absent.
- **Timestamp:** integer parse works; inputs with 13+ characters are treated as milliseconds. That heuristic mishandles signs/ambiguous digit widths and conflicts with broader timestamp expectations. The picker is limited to 1970–2100; DST/timezone-change cases are untested.
- **UUID:** cryptographically intended v4 generation and batch 1–1000 work. Copy is available; file export and a generated-set duplicate assertion are absent.

## Diff checker

- Basic text line/character diff, JSON normalization, summary/history-in-memory, and manual left/right text inputs are functional.
- Default options normalize data (including JSON key order/line treatment), so users may miss literal differences unless the mode is clear.
- File tab says “two files or two ZIP archives” but routes through the developer text-file picker and never connects the ZIP comparison service (`diff_page.dart:274`).
- Windows Git action only probes `git --version`. There is no repository selection or commit/branch comparison UI.
- A root GitHub repository URL has no blob path for `fetchFileContent`; the UI explicitly reports ZIP comparison is not implemented (`diff_page.dart:336-365`).
- Export only shows “Exporting as …” (`diff_page.dart:470`) and does not create a file. History is lost on navigation/restart. The GitHub client has no timeout, cancellation, or response cap.

## Snippets and settings

- Snippet CRUD, text/tag search, copy, validation, and Hive persistence exist. Import/export advertised in README is absent. Strict map casts can fail load after corruption/schema drift; `_loadSnippets` does not convert errors to `AsyncValue.error`.
- New ID selection from current maximum is not safe under concurrent writes. Sorting and conflict policy are weak; large collections are not paged.
- Light/dark/system theme selection and persistence work. Theme load errors are unhandled.
- Clear Data covers all `LocalStorage.knownBoxes`, including vault boxes, but live provider state is not invalidated, allowing stale views until recreation/restart.
- About/privacy/version/release content is incomplete or inconsistent; backup clipboard export can expose every persisted secret.

## Release conclusion by feature

The locally computed, low-volume transformations are closest to release quality. API, backup/import, external overwrite, large-input regex/JSON/Markdown/diff, and advanced Diff claims are not release-ready. Product documentation must be reduced to verified behavior before any public candidate.
