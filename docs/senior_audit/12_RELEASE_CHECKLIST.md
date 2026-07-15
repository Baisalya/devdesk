# DevDesk Release Checklist

This checklist applies to the final signed artifacts, not merely a debug build. Store evidence beside the release tag. Items are intentionally unchecked because the audit does not authorize remediation.

## Code and scope

- [ ] Release feature list matches reachable, functional UI.
- [ ] Diff file/ZIP/Git/GitHub/export claims are completed and tested or removed.
- [ ] `dart format --output=none --set-exit-if-changed .` passes.
- [ ] `flutter analyze` passes with the release SDK.
- [ ] No TODO/stub/no-op action is presented as complete.
- [ ] No generated/temp/private build artifacts are unintentionally tracked or packaged.
- [ ] Version, build number, application name, and identifiers are intentional.
- [ ] Changelog and release notes describe only verified behavior.

## Dependencies and supply chain

- [ ] Discontinued runtime dependencies are removed or risk-accepted with a deadline.
- [ ] `flutter pub outdated` reviewed; upgrades are staged, not bulk-applied.
- [ ] Lockfile is reviewed and committed intentionally.
- [ ] SBOM and third-party notices are generated and reviewed.
- [ ] Current authoritative vulnerability/advisory sources are checked.
- [ ] Package publishers/provenance and licenses are reviewed.
- [ ] Clean, pinned CI can reproduce each artifact.

## Security and privacy

- [ ] No hardcoded secret, private endpoint credential, keystore, password, or service-account file is tracked.
- [ ] Secret threat model and sink inventory are approved.
- [ ] API secrets use the approved protected store/reference model.
- [ ] History, reports, errors, snippets, clipboard, export, and backup pass canary redaction tests.
- [ ] Reveal/copy/export actions are explicit and masked by default.
- [ ] Privacy policy matches every observed data flow and platform difference.
- [ ] API, GitHub, URL-check, remote-resource, clipboard, local-storage, and backup disclosures are complete.
- [ ] Security/support contact and vulnerability response process exist.
- [ ] Screenshot/screen-sharing and clipboard limitations are documented.

## API tester

- [ ] GET/POST/PUT/PATCH/DELETE/HEAD/OPTIONS behavior is correctly scoped and tested.
- [ ] Query/header/body encoding and content type are wire-byte tested.
- [ ] URL-encoded form and advertised multipart behavior are correct.
- [ ] Connect, idle-read, and total deadlines are enforced.
- [ ] Response preview has byte/memory limits and binary behavior.
- [ ] Cancel stops stream, state updates, persistence, assertions, extraction, and collection iteration.
- [ ] Repeated Send and out-of-order completions cannot create stale/wrong results.
- [ ] DNS/TLS/offline/redirect/compression/empty/invalid JSON cases are tested.
- [ ] History/reports have retention and clear controls.
- [ ] Android HTTP/localhost/self-signed and web CORS/mixed-content limits are explained.
- [ ] Import/export versions and secret defaults are enforced.

## Hive and local data

- [ ] Startup reaches a recovery UI on storage failure.
- [ ] Authoritative schema versions, validators, migrations, and rollback exist.
- [ ] Corrupt/legacy/future records cannot crash the whole app silently.
- [ ] Disk-full/interrupted-write behavior is tested.
- [ ] Multi-instance Windows behavior is defined.
- [ ] Clear Data cancels pending writes, clears all boxes, invalidates providers, and verifies restart state.
- [ ] Android OS backup/data-extraction rules match sensitivity decisions.
- [ ] Retention/pruning exists for histories, reports, versions, and large collections.

## External files

- [ ] Android uses system picker without broad storage permissions.
- [ ] Windows open/save/overwrite dialogs pass native manual tests.
- [ ] UTF-8/BOM/UTF-16/invalid bytes and LF/CRLF behavior is defined and tested.
- [ ] Binary-renamed-text, empty, huge, unsupported extension, and wrong MIME cases fail safely.
- [ ] Read-only/locked/missing/renamed/deleted/symlink/network/long paths are tested.
- [ ] Overwrite uses temp write, flush/close, same-filesystem atomic replace where supported, and recovery fallback.
- [ ] Disk-full/kill-at-each-phase preserves the original.
- [ ] Dirty documents survive/confirm in-app back and OS/window close.

## Backup and import

- [ ] Type, version, app/build/schema metadata and included sections are validated.
- [ ] Future unsupported versions are rejected without mutation.
- [ ] Size, depth, count, enum/date/key/value constraints are enforced.
- [ ] Preview lists all boxes/record counts/conflicts and secret sensitivity.
- [ ] Secrets are excluded by default; any protected export is explicit and documented.
- [ ] Replace and merge have deterministic conflict/duplicate policy.
- [ ] Import validates/stages completely before mutation.
- [ ] Snapshot/journal/rollback restores exact pre-import state after any failure/exit.
- [ ] Valid, empty, legacy, future, malformed, truncated, huge, deep, duplicate, partial-failure, repeat-merge, and disk-full cases pass.

## UI and accessibility

- [ ] Phone, tablet, 900×600, wide desktop, resize, split-screen, and browser zoom layouts pass.
- [ ] All primary flows are keyboard-only operable with visible focus.
- [ ] Core shortcuts are documented and do not conflict with text/browser behavior.
- [ ] Every control has an accessible name/state; results/errors/loading are announced.
- [ ] TalkBack and NVDA passes are recorded on release artifacts.
- [ ] 200% text/OS large fonts do not hide critical actions.
- [ ] Light/dark/high-contrast colors meet approved contrast targets.
- [ ] Touch targets, tooltips, hover, tab order, Escape/back, and destructive confirmation pass.
- [ ] Loading/empty/error/retry/cancel states exist for every asynchronous feature.

## Automated and manual testing

- [ ] All 135 legacy tests still pass or intentional replacements are reviewed.
- [ ] Every P0/P1 has a failing-before/passing-after regression test.
- [ ] Hive tests use isolated temporary directories and clean resources.
- [ ] HTTP tests use realistic delayed/stalled/large/binary fake streams.
- [ ] Archive/input malicious corpus runs in CI.
- [ ] Integration tests cover startup, request, storage, file, backup, clear, and dirty-document flows.
- [ ] Performance budgets pass on low-end Android and baseline Windows.
- [ ] Manual cases in `13_MANUAL_TEST_CASES.md` run on the final signed bits.

## Android release

- [ ] Package `com.baishalya.devdesk` and display name are final.
- [ ] Version/build number and minimum/target SDK policy are final.
- [ ] Release build fails closed without production signing secrets.
- [ ] Upload/app-signing keys are protected, backed up, and recovery documented.
- [ ] APK/AAB signer and non-debuggable manifest are independently verified.
- [ ] INTERNET is justified; no broad storage permission exists.
- [ ] Network security and cleartext policy are intentional.
- [ ] Backup/data extraction rules are intentional.
- [ ] R8/obfuscation and symbol mapping decision is recorded.
- [ ] Icon/splash and all density assets are visually verified.
- [ ] Privacy URL, Data Safety, content rating, support, screenshots, and feature graphic are complete.
- [ ] Clean install, upgrade, rollback/internal track, Android 24/current, phone/tablet pass.

## Windows release

- [ ] Product/company/file metadata and icon are correct.
- [ ] Installer or portable ZIP format is selected and complete.
- [ ] All DLLs/data/plugins/runtime prerequisites are included.
- [ ] Executable/package is Authenticode signed and timestamped.
- [ ] Standard-user install, launch, update, rollback, uninstall, and data-retention behavior pass.
- [ ] Unicode/space/long install and file paths pass.
- [ ] SmartScreen/reputation and support guidance is prepared.
- [ ] Portable ZIP extraction/relocation/offline run is verified if offered.

## Web and other targets

- [ ] Web title/manifest/icons and supported limitations are intentional.
- [ ] CORS/mixed-content/files/clipboard/storage behavior is documented and tested if web is advertised.
- [ ] iOS/macOS/Linux are not advertised until build, core flows, file behavior, tests, and limitations are verified.

## Legal, store, artifact, and rollback

- [ ] `LICENSE` exists and matches README claims.
- [ ] Third-party notices and privacy/support/security links are packaged/published.
- [ ] Store screenshots/text were reviewed against the final code.
- [ ] Release artifact inventory excludes source secrets, temp files, debug symbols unless intentionally separated, and local data.
- [ ] SHA-256 is generated for each immutable artifact and published over a trusted channel.
- [ ] Symbols are retained securely for supported crash diagnosis; monitoring/no-monitoring decision is disclosed.
- [ ] Git tag points to the exact reproducible source/lockfile.
- [ ] Rollback artifacts, signing access, data-schema downgrade policy, and incident owner are ready.
- [ ] Independent go/no-go review confirms zero open P0/P1 and records accepted P2.
