# Testing and Release Report

**Verification date:** 2026-07-22  
**Targets:** Android and Windows  
**Application version:** `1.0.0+1`

## Automated results

| Gate | Result |
| --- | --- |
| `flutter analyze` | Passed, no issues |
| Full `flutter test` | Passed, 384 tests |
| Workspace foundation tests | Passed |
| Markdown knowledge tests | Passed |
| OKF tests | Passed |
| API body/security tests | Passed |
| OpenAPI parser/comparison tests | Passed |
| Git temporary-repository integration tests | Passed |
| Unified search/reference tests | Passed |
| AI/MCP policy tests | Passed |
| Responsive OpenAPI 360/900 px tests | Passed |
| `flutter build windows --release` | Passed; `build/windows/x64/runner/Release/devdesk.exe` |
| `flutter build apk --debug` | Passed; `build/app/outputs/flutter-apk/app-debug.apk` |

The test suite includes storage migration and rollback, malicious archive/import cases, redaction, bounded networking, external file identity and rollback faults, lifecycle behavior, shortcuts/accessibility, and a multi-viewport responsive matrix.

## Release blockers outside source control

- Android release AAB/APK cannot be declared store-ready until the owner supplies real upload signing material. The build guard intentionally rejects debug or absent release signing.
- A physical Android device matrix, including freeform/multi-window and document picker behavior, has not been executed in this environment.
- Windows distribution needs Authenticode signing, installer/portable packaging, and clean-VM/SmartScreen verification.
- `docs/privacy-policy.html` must be hosted at a stable public HTTPS URL and entered in Play Console.
- Store listing, Data safety form, content rating, screenshots, support URL, and staged rollout remain publisher tasks.

## Known limitations

- Android persisted SAF workspace editing is not implemented.
- Local workspace images are not rendered in the Markdown preview.
- OKF multi-file generation is per-file safe, not transactionally rolled back as one unit.
- OpenAPI comparison covers high-value structural breaking changes, not complete JSON Schema compatibility.
- API proxy, custom CA/client certificate, binary multipart file parts, and stream-response-to-file are unavailable.
- AI providers and MCP servers are intentionally not enabled.
- Subscription commerce remains off; the current product is free. Existing entitlement scaffolding is reserved for a future transparent launch that keeps documented basic features free.

## Reproduction

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter compact
flutter build windows --release
flutter build apk --debug
```

For signed distribution, follow `docs/release/ANDROID_SIGNING.md`, `docs/release/WINDOWS_DISTRIBUTION.md`, and `docs/release/RELEASE_RUNBOOK.md`.
