# Secret Threat Model

## Assets

API bearer/basic credentials, API keys, cookie/header values, environment values, URL query credentials, request bodies, extracted variables, responses, collection exports, history, reports, snippets, backups, and clipboard output.

## Protection goals

1. Secret values must not be stored in ordinary API workspace Hive records.
2. Portable data must exclude protected secrets by default.
3. Errors and UI feedback must not echo raw sensitive material.
4. Cancellation and disposal must prevent a completed operation from persisting or publishing stale sensitive output.
5. Clear Data must clear both ordinary records and platform-protected secret records.

## Platform boundaries

- **Android:** secret overlay encrypted with AES/GCM; key generated and held by Android Keystore. Ciphertext is stored in private SharedPreferences.
- **Windows:** secret overlay encrypted/decrypted with DPAPI scoped to the current Windows user; ciphertext is stored in the user's application data.
- **Web:** protected persistent secret storage is unavailable. Secret-saving UI results in session-only behavior and an actionable warning.

## Explicit non-goals

The design does not protect against an already-compromised OS account, administrator/debugger access, malware reading process memory, screen capture, clipboard history, accessibility-service abuse, or secrets deliberately exported/shared by the user. It does not provide team sharing, cloud escrow, password recovery, or cross-device secret migration.

## Migration

Legacy API workspace records are parsed one at a time. When protected storage is available, the secret-only overlay is written first and ordinary storage is rewritten without secrets. If protection fails or is unavailable, plaintext secret fields are removed from ordinary storage and the user is warned to re-enter session values. Invalid workspace records are moved to a redacted quarantine.

## Sink policy

- Ordinary API workspace persistence: sanitized model only.
- Protected store: secret-only path/value overlay.
- History/reports/collections/backups: sanitized and deep-redacted.
- Clipboard: common `SafeClipboard` boundary; high-risk surfaces force redaction.
- Errors: `DataRedactor.safeError`; no raw exception body/URL/path.
- Markdown remote images: blocked.
- Tests: disposable `CANARY_*` strings only.
