# DevDesk

DevDesk is an **offline-first Flutter developer toolbox** for Android, Windows, and an explicitly limited web build. Most tools process content locally. Network access occurs only when the user starts an API request or a supported GitHub fetch; DevDesk does not include analytics, telemetry, accounts, cloud sync, or a backend.

## Release scope

The release scope includes:

- Markdown editing and local Markdown vault
- README generation
- JSON validation, formatting, minification, and accessible tree view
- API workspaces with environments, collections, assertions, bounded streamed responses, cancellation, history, and redacted exports
- Local JWT decoding without signature verification
- Regex, Base64, URL, timestamp, and UUID utilities
- Text diff with bounded worker execution and redacted export
- Local snippets and notes
- Versioned backup/restore with pre-validation, staging, persistent rollback journal, and secret exclusion
- User-selected external Markdown, JSON, text/code, backup, and API collection files

Features not listed above must not be advertised as production-ready. In particular, DevDesk does not provide Git working-tree integration, arbitrary repository cloning, cloud synchronization, remote AI, or certificate-bypass behavior.

## Security and privacy boundaries

- API secrets are removed from ordinary Hive workspace records. Android uses Android Keystore-backed encryption and Windows uses DPAPI for the secret overlay.
- Browser storage cannot provide an equivalent platform secret boundary; web secrets are session-only and are not persisted.
- Backups and portable exports exclude protected secrets and conservatively redact secret-like values.
- Clipboard actions for API data, JWT claims, JSON, snippets, Markdown, vault content, diffs, and backups pass through a common redaction boundary.
- Remote Markdown images are not loaded. This avoids unrequested network traffic and tracking pixels.
- Release Android builds fail when production signing is not configured. No debug key is accepted for release.

See `PRIVACY.md`, `SECURITY.md`, and `docs/release/PLATFORM_LIMITATIONS.md` for the complete boundaries.

## External files

Android uses the system document picker and treats selected documents as read copies; edited content is saved through a user-selected destination. Windows can overwrite a selected local file only after a same-directory temporary write, flush/close, identity revalidation, and native atomic replacement. Network paths and reparse/symbolic-link paths are not overwritten in place.

Text decoding supports UTF-8, UTF-8 BOM, UTF-16 LE/BE BOM, and preserves detected line endings on overwrite. Binary, malformed, oversized, missing, renamed, locked, or read-only files fail with actionable errors while preserving the original.

## Build prerequisites

- Flutter **3.41.9 stable** (framework revision recorded in `.metadata`)
- Dart supplied by that Flutter SDK
- Android SDK/JDK 17 for Android
- Visual Studio with Desktop development with C++ for Windows

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test --coverage
flutter build apk --debug
flutter build web
```

Windows verification must run on Windows:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build windows
```

Release Android APK/AAB builds require external signing configuration described in `docs/release/ANDROID_SIGNING.md`. A build failure without those credentials is intentional.

## Project structure

- `lib/app`: routing, theme, and command registry
- `lib/core`: storage, security, bounded networking, archive policy, platform bridges, file safety, and shared widgets
- `lib/features`: feature-specific UI, state, models, and services
- `test`: unit, widget, fault-injection, malicious-input, and lifecycle regression tests
- `docs/senior_audit`: original senior audit reports
- `docs/release`: remediation evidence and release runbooks
- `tool/release`: source/Windows packaging and third-party notice tooling

## Release status

The remediation branch contains production code and regression tests, but a public release remains blocked until the final Flutter test/build matrix runs on supported hosts and real Android/Windows signing credentials are supplied. See `docs/release/VERIFICATION_REPORT.md`.

## License and support

DevDesk source is licensed under the MIT License; see `LICENSE`. Third-party packages retain their own licenses; generate the exact resolved notice bundle with `dart run tool/release/generate_third_party_notices.dart` after dependency resolution.

Security reports should follow `SECURITY.md`. General support is handled through the repository issue tracker as described in `SUPPORT.md`.
