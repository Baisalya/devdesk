# API Tester Security and Reliability Audit

## Request architecture

The quick client uses Riverpod request/header/query/body state, validates HTTP(S), composes an `http.Request`, sends through an injected `http.Client`, buffers `Response.fromStream`, formats the result, and optionally persists history. API Workspaces add workspaces, collections/folders, variables/auth, assertions, extraction, run reports, imports/exports, and explicit client cancellation.

The core request path is real, not UI-only. It is nevertheless the highest-risk module because network lifecycle and secret lifecycle are incomplete.

## Capability findings

| Area | Current behavior | Audit result |
| --- | --- | --- |
| Methods | Quick: GET/POST/PUT/PATCH/DELETE; workspace also exposes HEAD/OPTIONS | Implemented |
| URL/query | HTTP(S) validation and `Uri.replace` query merge | Functional; duplicate query keys collapse in map state |
| Headers | User headers plus auth/content type | Functional; duplicate header names cannot be retained |
| JSON/plain body | Supported | Functional for common text payloads |
| Form URL encoded | UI/model has fields, executor sends prepared body | Likely broken: form fields are not encoded into the body in the execution path |
| Multipart | Text fields supported | Partial: no file parts despite “multipart” expectation |
| Redirect/compression | Delegated to `package:http` defaults | No explicit UI/control/tests |
| Response | Status, time, headers, text/pretty JSON | Entire stream buffered; no binary/save/stream/cap |
| Environments | Workspace hierarchy and variable resolution; quick path primarily `baseUrl` | Partial; unresolved variables detected in workspace |
| Auth/secrets | Header/auth/secret flags and import warning | Unsafe persistence/redaction boundaries |
| Assertions/extraction | Status/body/header/time plus JSON/header/regex extraction | Useful, simplified; regex remains UI-isolate/resource risk |
| History/reports | Hive-persisted, subset shown | Unbounded growth; response data can retain secrets |
| Collection runner | Sequential run with optional delay/report | Cancellation can close one client but does not reliably stop subsequent items |
| Import/export | DevDesk and shallow Postman import | No cURL/OpenAPI/HAR; version compatibility not enforced |
| Code generation | Quick API snippets for common languages | Can reproduce sensitive headers/body into clipboard; workspace UI claim is incomplete |

## Detailed release issues

### DD-SEC-001: API secrets are stored and exported without a reliable protection boundary

- Severity: P0
- Category: Security
- Status: Confirmed
- Platforms: All
- Evidence:
  - `lib/features/api_tester/provider/api_workspace_storage.dart:27-30,52-55`
  - `ApiWorkspaceStorage.saveWorkspace` and `saveHistory`
  - `lib/features/api_tester/models/api_workspace_models.dart:948-1083`
  - `lib/core/storage/local_storage.dart:78-94`
- Current behaviour: Workspace definitions are always serialized with `includeSecrets: true`; Hive is not encrypted. History sanitation is conditional and incomplete. Whole-box backup/clipboard export includes workspace data.
- Expected behaviour: Secret values must have an explicit threat model, separate protected persistence, safe default exclusion, masked UI, redacted history/logs/snippets, and prominent export disclosure.
- User impact: API keys, bearer tokens, cookies, and environment values can remain on disk or enter a portable JSON file despite user expectations.
- Security or business impact: Credential compromise, privacy-policy breach, and loss of trust in the core local-first promise.
- Root cause: A display/model `saveSecrets` flag is treated as sanitation policy while the storage adapter unconditionally requests secret-inclusive serialization.
- Recommended fix: Inventory every secret source/sink; separate secret references from workspace documents; use platform-backed key storage or an explicitly keyed encrypted vault; exclude secrets from backup/export by default; provide migration and destructive-reset recovery.
- Verification steps: Seed canary secrets in every header/auth/query/body/environment/response field; save/restart/export/backup/import/generate snippets; assert no canary appears outside the approved vault and opt-in export.
- Estimated complexity: Large

### DD-API-001: Timeout ends at headers and responses are buffered without a size bound

- Severity: P1
- Category: Reliability/Security
- Status: Confirmed
- Platforms: All
- Evidence:
  - `lib/features/api_tester/provider/api_provider.dart:331-332`
  - `lib/features/api_tester/utils/api_workspace_executor.dart:22,71,83`
  - `http.Response.fromStream`
- Current behaviour: `client.send(...).timeout()` covers connection/headers. Reading the response stream happens afterward with no read deadline, byte cap, streaming UI, binary policy, or cancellation token.
- Expected behaviour: Separate connect/header and idle/total read limits, capped streaming, explicit truncation/save behavior, correct raw byte accounting, and cancellation throughout.
- User impact: A slow/infinite or enormous endpoint can hang, exhaust memory, or crash the app.
- Security or business impact: User-triggered denial of service; unreliable API testing against untrusted endpoints.
- Root cause: Conversion to a fully buffered `http.Response` before applying resource policy.
- Recommended fix: Consume `StreamedResponse.stream` incrementally, enforce total bytes and read/total deadlines, preserve bytes/content type, allow bounded preview or safe file save, and expose clear cancellation/error states.
- Verification steps: Fake client streams delayed headers, stalled chunks, infinite chunks, oversized bodies, binary bytes, and cancellation; assert bounded time/memory and no persistence after cancel.
- Estimated complexity: Large

### DD-API-002: Workspace cancellation and concurrent execution are not state-safe

- Severity: P1
- Category: Reliability
- Status: Confirmed
- Platforms: All
- Evidence:
  - `lib/features/api_tester/provider/api_workspace_provider.dart:186,631-652,679-769`
  - `_activeClient`, `sendSelectedRequest`, `cancelRequest`, and collection runner
- Current behaviour: A single mutable `_activeClient` is replaced per operation. Earlier completions/finally blocks can mutate state after a newer request begins. Closing the collection-run client does not guarantee the loop stops before later requests.
- Expected behaviour: One owned operation identity per request/run, stale-completion rejection, deterministic cancel, and UI idempotency even when provider methods are invoked repeatedly.
- User impact: Wrong response displayed, incorrect sending state, unexpected later requests after cancel, and misleading run reports.
- Security or business impact: Unintended non-idempotent API calls and loss of confidence in test results.
- Root cause: Client lifecycle doubles as cancellation/state identity; no operation generation/token or serialized execution contract.
- Recommended fix: Model a request/run operation with ID, cancellation signal, terminal-state guard, and `mounted`/dispose checks; disable/serialize duplicate actions in UI and provider; stop collection iteration immediately.
- Verification steps: Concurrent fake requests finishing out of order, repeated Send calls, cancel during each phase/delay, provider disposal, navigation, and app lifecycle interruption.
- Estimated complexity: Medium

### DD-API-003: Secret redaction misses URLs, bodies, responses, and generated snippets

- Severity: P1
- Category: Security/Privacy
- Status: Confirmed
- Platforms: All
- Evidence:
  - `lib/features/api_tester/models/api_workspace_models.dart:601-655,1159-1188`
  - `ApiRequestItem.sanitized` and `ApiHistoryItem.sanitized`
  - quick API code snippet generation and backup export paths
- Current behaviour: Known sensitive header/auth/variable values can be stripped, but URL query secrets remain, request bodies are inconsistently covered, full response headers/body can persist, and generated snippets can contain credentials.
- Expected behaviour: Context-aware redaction across request, response, errors, history, reports, clipboard, snippets, screenshots, imports, and backups, with opt-in reveal/export.
- User impact: A user can disable secret saving yet retain credentials or sensitive payloads elsewhere.
- Security or business impact: Accidental disclosure through files, screen sharing, clipboard managers, or support bundles.
- Root cause: Field-specific sanitation is spread across model copies instead of a centralized data-classification/output policy.
- Recommended fix: Define sensitivity labels and sink-specific serializers; redact query/body/response using explicit user markings plus conservative known-name rules; never promise content scanning is perfect.
- Verification steps: Canary matrix across header, cookie, auth, URL, body, multipart, environment, response, assertion/extraction, error, history, report, snippet, collection export, and backup.
- Estimated complexity: Large

### DD-API-004: Form and multipart behavior does not match the advertised request model

- Severity: P1
- Category: Functional correctness
- Status: Confirmed for missing multipart files; form execution requires focused regression confirmation
- Platforms: All
- Evidence:
  - `lib/features/api_tester/utils/api_workspace_utils.dart:188`
  - `lib/features/api_tester/utils/api_workspace_executor.dart:44-83`
  - Request composer form fields/body preparation
- Current behaviour: Multipart adds text fields but no file parts. URL-encoded form values are modeled separately while the standard request path sends `prepared.body`, which is not populated from those fields in the observed flow.
- Expected behaviour: Correct percent-encoded form body/content type; multipart text and file parts; explicit file size/content type; deterministic snippets/import/export.
- User impact: Requests differ from what the UI displays, producing server errors or silently wrong tests.
- Security or business impact: False confidence in API behavior and possible submission of incorrect data.
- Root cause: UI model and executor payload representations diverged.
- Recommended fix: Use one validated prepared-request representation with exact bytes and headers. Do not advertise multipart files until picker, bounds, preview, cancellation, and tests exist.
- Verification steps: Mock server/fake client assertions for Unicode/reserved form fields, empty/repeated values, multipart boundaries, text/binary files, content length/type, cancel, import/export, and snippets.
- Estimated complexity: Medium

## Network and platform risks

- Android has INTERNET permission and default platform certificate validation. No certificate-bypass code was found.
- The UI accepts `http://`. Android target 36 blocks cleartext by default without a network security exception, producing platform-specific failure with no explanatory warning. Windows may send it. Web may block it as mixed content.
- Self-signed certificates, proxies, client certificates, cookie jars, DNS/IPv4/IPv6 selection, and localhost/emulator semantics are not controlled or documented.
- Web requests are subject to CORS, forbidden headers, credential policy, preflight, and browser response-header exposure. A successful web build does not make the API client equivalent to native.
- Error strings are often surfaced directly; no systematic secret-safe error adapter exists.

## Required release fixes

1. Resolve DD-SEC-001 with a documented secret threat model and migration.
2. Implement bounded streamed responses, connect/read/total timeout semantics, binary handling, and end-to-end cancellation.
3. Make operation state generation-safe and collection cancellation terminal.
4. Centralize sink-specific redaction and safe export/clipboard behavior.
5. Fix/test form payloads; either implement or remove multipart-file claims.
6. Cap/prune history and reports; add clear retention controls.
7. Explain HTTP, TLS/self-signed, localhost, proxy, and web CORS limits in-product.
8. Add mocked executor/provider tests before migrating `http` to 1.x.

GraphQL, WebSocket/SSE, proxy, certificates, cookie jars, and scripting are market features, not release blockers for DevDesk. cURL import/export is the highest-value post-baseline interoperability addition.
