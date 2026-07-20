# Release Runbook

1. Freeze the release branch and dependency lockfile.
2. Run `tool/release/verify_release.sh` on Linux/Android-capable CI and the equivalent commands on Windows.
3. Generate and review `THIRD_PARTY_NOTICES.generated.md` from the resolved package cache.
4. Run malicious-input, storage rollback, external-file, HTTP stream/cancellation, keyboard, semantics, and platform manual tests.
5. Build Android debug for smoke testing. Build release APK/AAB only with the real upload key; verify signer and hashes.
6. Build Windows release, package with `package_windows.ps1 -RequireSignature`, verify extraction/inventory/signatures/hashes on a clean VM.
7. Build web only if the documented CORS/storage/secret limitations are accepted and tested.
8. Review store/privacy/support text against the final code and artifact permissions.
9. Tag the exact source/lockfile commit. Store immutable hashes, symbols, notice bundle, test reports, and signing fingerprints beside the tag.
10. Perform independent go/no-go review. Zero open P0/P1 is required.

## Rollback

Retain the prior signed Android internal-track artifact and prior signed Windows portable ZIP. Record storage schema compatibility before authorizing rollback. Never distribute an older build that cannot safely read the migrated data. Restore from a verified backup only after testing the exact backup/app-version combination.

## Incident response

Stop distribution, preserve hashes/logs without sensitive payloads, revoke/rotate affected release or API credentials under the responsible owner's authority, publish a scoped advisory, and ship a tested signed update. DevDesk does not include remote kill-switch or telemetry capability.
