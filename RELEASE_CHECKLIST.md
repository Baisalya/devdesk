# DevDesk Release Checklist

This checklist records automated evidence separately from owner-controlled and
manual release work. A checked build item does not make an unsigned artifact a
public release candidate.

## Automated quality gates

- [x] `flutter pub get`
- [x] `dart format --output=none --set-exit-if-changed .`
- [x] `flutter analyze` with no issues
- [x] `flutter test --coverage` (184 passing tests; 52.86% line coverage)
- [x] Malicious ZIP, bounded HTTP, cancellation, secret-redaction, storage
  migration, backup rollback, and atomic-file failure tests
- [x] Android debug APK build
- [x] Windows release bundle build
- [x] Web release build and Wasm dry run
- [ ] Android release APK/AAB signed with the real externally provisioned key
- [ ] Windows portable bundle signed, timestamped, and verified with the real
  Authenticode certificate

## Product and platform checks

- [ ] Smoke-test every advertised tool on supported Android and Windows
  devices, including invalid, empty, and maximum-size inputs.
- [ ] Verify API timeouts, cancellation, redirects, binary responses, large
  responses, and offline failures against controlled endpoints.
- [ ] Verify Android Keystore and Windows DPAPI secret save/load/delete behavior
  across restart, upgrade, lock, corruption, and user-data clearing.
- [ ] Verify backup merge/replace, interrupted import recovery, future-schema
  rejection, and downgrade/rollback behavior on copies of realistic data.
- [ ] Verify Windows atomic overwrite, conflict detection, read-only/locked
  files, Unicode/spaces/long paths, network-path refusal, and recovery files.
- [ ] Test TalkBack and Windows screen readers, keyboard-only navigation, text
  scaling, contrast, focus order, and dirty-window close confirmation.
- [ ] Profile large JSON, regex, diff, ZIP, folder, and API workloads on minimum
  supported hardware.
- [ ] Test the web build with the documented browser storage, CORS,
  mixed-content, file, and session-only secret limitations.

## Privacy and security review

- [x] Privacy copy states that ordinary data is local and that network access
  occurs when the user sends API requests or explicitly fetches GitHub content.
- [x] Backups, histories, reports, portable collections, and common clipboard
  paths exclude or redact secret-like values by default.
- [x] Saved API workspace secrets are opt-in and use Android Keystore or Windows
  DPAPI; unsupported platforms keep them session-only.
- [x] Android requests Internet access but no broad storage permission, disables
  platform backup, and blocks cleartext traffic outside debug builds.
- [ ] Publish stable privacy, security, and support URLs and verify that store
  disclosures exactly match the final signed artifacts.
- [ ] Complete an independent security review and dependency/advisory review of
  the exact release commit and lockfile.

## Store and distribution work

- [x] Application ID is `com.baishalya.devdesk`; displayed name is `DevDesk`.
- [x] Version metadata is `1.0.0+1` and Windows resource metadata matches it.
- [x] MIT license, privacy, security, support, notices, metadata draft, release
  runbook, and rollback guidance are present.
- [ ] Supply final Android/Windows icons, Play screenshots, feature graphic, and
  approved listing copy.
- [ ] Complete Play content rating, data-safety, target-SDK, and policy forms.
- [ ] Generate and review third-party notices from the final lockfile.
- [ ] Verify signed artifact hashes and inventories on clean supported devices
  or VMs, then archive evidence beside the immutable release tag.
- [ ] Obtain an independent go/no-go decision with zero open P0/P1 issues.

Until every signing, manual, owner-input, and clean-environment item above is
complete, the public release decision remains **HOLD**.
