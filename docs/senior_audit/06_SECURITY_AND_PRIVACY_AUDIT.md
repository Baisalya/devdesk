# Security and Privacy Audit

## Scope and baseline

The audit searched source, manifests, build settings, assets, documentation, and tracked artifacts for credentials, private endpoints, signing material, logging, file/network/storage risks, and privacy claims. No committed production API key, password, token, private signing keystore, service-account file, or broad Android storage permission was found. This does not make persisted user secrets safe.

Assessment references include OWASP MASVS (storage, cryptography, network, platform, resilience, and privacy): https://mas.owasp.org/MASVS/, Android network security configuration: https://developer.android.com/privacy-and-security/security-config, and Android backup guidance: https://developer.android.com/privacy-and-security/risks/backup-best-practices.

## Confirmed vulnerabilities and release risks

| ID | Severity | Finding | Evidence |
| --- | --- | --- | --- |
| DD-SEC-001 | P0 | API secrets are persisted/exported without a reliable protected boundary | `api_workspace_storage.dart:29,54`; `local_storage.dart:78-94` |
| DD-REL-001 | P0 | Android release uses debug signing | `android/app/build.gradle.kts:30-34`; signer inspection |
| DD-BACKUP-001 | P0 | Replace import can clear/partially update data without rollback | `local_storage.dart:98-120` |
| DD-API-003 | P1 | Redaction misses URL/body/response/snippet sinks | `api_workspace_models.dart:601-655,1159-1188` |
| DD-SEC-002 | P1 | ZIPs are decompressed before expanded-resource enforcement | `vault_export_service.dart:49-68`; `folder_diff_service.dart:83-87` |
| DD-FILE-001 | P1 | Direct external overwrite can corrupt the only copy | `external_file_service.dart:88-94` |
| DD-PRIV-001 | P1 | Absolute offline/privacy claims contradict network-capable code | `PRIVACY.md:5,25`; API/GitHub/vault network services |
| DD-PERF-001 | P1 | Unbounded untrusted input/response work enables local denial of service | regex/JSON/Markdown/diff/API paths |

### DD-SEC-002: Archive decompression can exhaust memory before safety checks

- Severity: P1
- Category: Security/Availability
- Status: Confirmed
- Platforms: All
- Evidence:
  - `lib/features/markdown/vault/provider/vault_export_service.dart:49-68`
  - `lib/features/diff_checker/provider/folder_diff_service.dart:83-87`
  - `ZipDecoder().decodeBytes`
- Current behaviour: Vault checks compressed input length, then decodes the entire archive in memory and only afterward sums entry sizes. Diff ZIP decode has no comparable declared cap in the service.
- Expected behaviour: Reject unsafe archive metadata before allocation where possible, enforce entry/count/path/compression-ratio/total-expanded limits while streaming, reject symlinks/special files, and support cancellation.
- User impact: A small malicious or accidental ZIP can freeze or crash the app.
- Security or business impact: Local denial of service and possible data loss from unsaved work.
- Root cause: Post-decompression validation and whole-archive APIs.
- Recommended fix: Move to bounded streaming extraction/inspection, cap entries/name length/nesting/ratio/expanded bytes, validate normalized paths and link types, and run heavy work off the UI isolate.
- Verification steps: High-ratio zip bomb, nested archive, millions of empty entries, oversized metadata/name, traversal, absolute/drive paths, symlink, encrypted/truncated/CRC-bad ZIP, cancellation, and memory benchmark.
- Estimated complexity: Large

### DD-PRIV-001: Privacy and offline claims do not match actual network behavior

- Severity: P1
- Category: Privacy/Documentation
- Status: Confirmed
- Platforms: All
- Evidence:
  - `PRIVACY.md:5` — personal data “never leaves your device”
  - `PRIVACY.md:25` — no internet required for any other feature
  - `README.md:3`
  - `lib/features/diff_checker/provider/github_service.dart:50-72`
  - API tester and vault external-URL checker
- Current behaviour: The policy opens with an absolute no-transmission statement, later acknowledges API requests, and omits or understates GitHub Diff and vault URL-check networking. Markdown remote image behavior lacks an explicit policy. JWT copy says “in your browser” for a cross-platform app.
- Expected behaviour: Say local by default, enumerate every intentional network trigger, identify destination/control, describe stored/exported data and secrets, and distinguish native from web behavior.
- User impact: Users may paste sensitive content under an inaccurate understanding of transmission and persistence.
- Security or business impact: Deceptive privacy representation, store-review/compliance risk, and loss of trust.
- Root cause: Marketing language was not reviewed against feature-level data flows.
- Recommended fix: Build a data-flow inventory and rewrite README/policy/in-product notices. Use “most transformations run locally”; state API requests go to user-selected endpoints; disclose GitHub/link checks/remote resources; document clipboard, local unencrypted storage, backup contents, retention, and deletion limits.
- Verification steps: Trace each feature with network interception on every target; compare observed destinations and persisted artifacts to every policy sentence and store Data Safety answer.
- Estimated complexity: Medium

## Secret management assessment

- Sensitive-name detection and default collection-import stripping are useful defense-in-depth, not a complete secret system.
- Workspace persistence explicitly serializes with secrets. Quick history can suppress known sensitive headers, but URLs and bodies still carry tokens. Responses, cookies, generated snippets, reports, clipboard content, and backups are separate disclosure sinks.
- Masking a field does not protect at rest. Hive boxes and backup JSON are readable by any process/person with equivalent local access.
- Encryption is valuable for API credentials, but requires Android Keystore/Windows DPAPI-or-Credential-Manager design, web limitations, key rotation, loss/reset, device migration, secret references, and legacy migration. Low-sensitivity preferences need not be encrypted.
- Screenshots and OS clipboard history cannot be made fully safe by the app. Provide reveal/copy expiry guidance and avoid placing secrets in snackbars/errors.

## Network assessment

- Platform TLS certificate validation is not bypassed. No custom trust-all client was found.
- Both clients accept HTTP(S), but Android target 36 blocks cleartext by default while Windows may permit it. There is no consistent cleartext warning or platform explanation.
- GitHub fetch and vault URL-check operations are user-triggered but have weak timeout/resource/privacy UX. URL checks disclose user-selected URLs to their hosts and possibly intermediaries.
- The API tester intentionally supports arbitrary endpoints, including localhost/private networks. This is expected for a developer tool, but redirects, proxy behavior, DNS rebinding-like endpoint changes, and response caps need a documented trust model.
- Web behavior is materially different due to CORS, preflight, mixed content, forbidden headers, credentials, and browser storage/clipboard constraints.

## File and local-data assessment

- No path extraction to disk was found in vault ZIP import; normalized path rejection exists. The decompression-before-limit issue remains.
- Direct external overwrite is not atomic. Files are strict UTF-8; wrong MIME/binary, symlink, network path, read-only, and encoding metadata are weakly handled.
- Android application backup behavior is not explicitly configured. `allowBackup` and data-extraction/backup rules are absent, so platform defaults may include app data depending on Android/version/transport. Sensitive boxes should be explicitly assessed/excluded according to current Android guidance.
- Clear Data clears declared boxes but not necessarily clipboard/exported files/OS backups and may leave in-memory provider state.

## Dependency risk

- `flutter_markdown` is discontinued; an explicit remote image/link/raw HTML policy and maintained renderer are needed.
- `http` 0.13.6 is an old major line; current request implementation risks are architectural, not fixed by version bump alone.
- `archive` 3.6.1 is behind 4.0.9; current denial-of-service risk comes from whole-memory use and post-decode checks. Do not claim a package CVE without a verified advisory.
- `diff_match_patch` is current on pub but old and lightly maintained; bound its workloads.
- `file_picker` is current at 11.0.2, which includes its recent Android path-traversal fix.

## Suspected / runtime-verification risks

### DD-PRIV-002: Remote Markdown resources may cause undisclosed network requests

- Severity: P2
- Category: Privacy
- Status: Needs Runtime Verification
- Platforms: Android/Windows/Web
- Evidence:
  - `lib/features/markdown/presentation/markdown_page.dart:700`
  - `Markdown(data: ...)` without explicit image/link callback or resource policy
- Current behaviour: Markdown content is passed to the renderer without a DevDesk policy. Package/platform behavior may fetch remote images; links may be inert or launch only when callbacks are provided.
- Expected behaviour: Default-block or clearly consent to remote resources, show destination, prevent automatic navigation, and document behavior per platform.
- User impact: Opening untrusted Markdown may reveal IP/user-agent/timing or render tracking content.
- Security or business impact: Contradicts offline expectations and expands untrusted-content attack surface.
- Root cause: Renderer defaults substitute for product security policy.
- Recommended fix: Add explicit callbacks/resolvers, block remote images by default, allow per-document load with warning, sanitize schemes, and test raw HTML/data/file/http(s) URLs.
- Verification steps: Network-intercept fixtures for remote image/link, redirect, data/file/javascript-like schemes, offline mode, and each platform.
- Estimated complexity: Medium

Other runtime checks: Android OS backup contents, clipboard retention, screenshot policy, TLS/self-signed behavior, Windows file ACL/locking/reparse behavior, and multi-instance Hive access.

## Recommended controls

1. Fix release signing and establish protected secret storage/export policy.
2. Make import and external overwrite recoverable before claiming data safety.
3. Bound all untrusted network/archive/text inputs and move demonstrated heavy work off the UI isolate.
4. Centralize safe errors/redaction and add canary-secret tests across every sink.
5. Define Android backup/data-extraction rules and Windows local-data/install/uninstall behavior.
6. Rewrite privacy/store disclosures from an observed data-flow inventory.
7. Add a security response contact, third-party notices, license file, dependency review cadence, and reproducible signed release process.

## Privacy conclusion

DevDesk is local-first in intent, but the current privacy claims do **not** accurately match the code. API secrets are **not handled safely**, and backup files should be treated as sensitive plaintext until the architecture changes.
