# Android and Windows Platform Notes

## Shared Flutter behavior

Material 3 navigation and responsive pages are tested at 280/320/360 px phone widths, landscape/freeform sizes, compact desktop, expanded desktop, and increased text scaling. API parsing, bounded networking, knowledge models, OKF, OpenAPI, unified search, privacy, rating, and subscription-entitlement scaffolding are shared.

## Android

- System picker reads and Save As flows are supported.
- Android Keystore protects API secret overlays.
- The current workspace model can represent document-tree grants, but a persisted SAF enumeration/write adapter is not implemented. It fails as unsupported rather than treating a content URI as a filesystem path.
- Git CLI workspace operations are unavailable.
- Debug APK build is verified. Public release requires owner-supplied upload signing, Play App Signing configuration, store privacy-policy URL, Data safety answers, screenshots, and real-device tests.
- Freeform/multi-window layouts are supported by responsive breakpoints, but OEM-specific runtime behavior still requires device testing.

## Windows

- Local folder workspaces support bounded enumeration, expected-fingerprint saves, file watching when enabled, and verified atomic replacement.
- DPAPI protects API secret overlays.
- Git CLI inspection and guarded local stage/unstage/discard are available when Git is installed.
- The x64 release build is verified. Distribution still requires an installer or portable bundle decision, Authenticode code signing, SmartScreen/reputation testing, and clean-VM verification.

## Unsupported common requests

No platform silently falls back for missing capabilities. Android SAF workspace writes, Android Git CLI, Windows network-path overwrite, symlink/reparse overwrite, certificate bypass, and background cloud synchronization are disabled with an explanation.
