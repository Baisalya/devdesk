# Windows Portable Distribution Runbook

DevDesk uses a verified portable ZIP configuration. The complete Flutter release bundle is packaged; copying only `devdesk.exe` is unsupported.

## Build

On a supported Windows build host with Visual Studio Desktop development with C++:

```powershell
flutter clean
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build windows
```

## Package

```powershell
powershell -ExecutionPolicy Bypass -File tool/release/package_windows.ps1
```

The script validates required runtime files, optionally Authenticode-signs executable/DLL files, creates an inventory with per-file SHA-256 hashes, creates a portable ZIP, extracts it to a temporary directory, compares the inventory, and emits the ZIP SHA-256.

To require signing, use `-RequireSignature`. Supply either a certificate already available to `signtool` through `DEVDESK_WINDOWS_CERT_SHA1`, or a PFX through `DEVDESK_WINDOWS_PFX_PATH` and `DEVDESK_WINDOWS_PFX_PASSWORD`. Timestamp URL is supplied through `DEVDESK_WINDOWS_TIMESTAMP_URL`.

## Update, rollback, and uninstall

Portable update: close DevDesk, back up the prior application folder, extract the new package to a new folder, verify its published hash/signature, then launch it. User data remains in the Windows profile and is not stored inside the portable application folder.

Rollback: close DevDesk and launch the prior verified portable folder. Data schema downgrade is not guaranteed; do not roll back after a storage migration unless the release notes explicitly authorize it and a backup was tested.

Uninstall: close DevDesk and remove the portable application folder. Local application data remains unless the user clears it inside DevDesk or removes the documented Windows profile data separately.

## Manual evidence required

Run on clean supported Windows VMs as standard and administrator users, with Unicode/spaces/long paths. Verify offline launch, file dialogs, atomic overwrite failures, DPAPI behavior, update/rollback, uninstall/data retention, signature, SmartScreen behavior, and SHA-256.
