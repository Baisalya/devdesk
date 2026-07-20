# Platform Limitations

## Android

- API Tester requires `INTERNET` and contacts only endpoints selected by the user.
- Release manifest rejects cleartext HTTP. Debug builds allow cleartext for local development only.
- `localhost` means the Android device/emulator itself, not the development computer. Emulator host access commonly uses the platform emulator gateway configured by the developer.
- Self-signed or invalid TLS certificates are not bypassed.
- External documents use Android's system picker. DevDesk does not request broad storage or all-files access and does not overwrite arbitrary filesystem paths.
- Application backup/data extraction is disabled for private DevDesk data.

## Windows

- API and file operations use the current Windows user's network/filesystem permissions.
- Protected secrets use DPAPI and are not portable to another Windows user or machine.
- In-place overwrite is limited to supported local regular files. Reparse points/symbolic links and network paths use Save As instead.
- Windows file locks, antivirus, controlled-folder access, and enterprise policy can prevent replacement.
- A portable distribution must include the full Flutter release bundle, not only `devdesk.exe`.

## Web

- Browser CORS and mixed-content rules can block API calls even when the endpoint is reachable from native apps.
- Browser storage is quota-bound and may be cleared by private browsing, policy, or the user.
- No equivalent protected persistent secret boundary is claimed; API secrets are session-only.
- Native path overwrite, DPAPI/Keystore, Windows dirty-close bridge, and native atomic replacement are unavailable.
- Clipboard access depends on browser permission and secure context.

## Unsupported release claims

iOS, macOS, and Linux source folders exist because this is a Flutter project, but those platforms are not public release targets until their builds, storage/file behavior, permissions, accessibility, and packaging are verified independently.
