# Build, Dependency, and Test Report

## Validation environment

| Component | Detected value |
| --- | --- |
| Host | Windows 11 25H2 |
| Flutter | 3.41.9 stable, revision `00b0c91f06`, 2026-04-29 |
| Dart | 3.11.5 |
| DevTools | 2.54.2 |
| Java | OpenJDK 21.0.10 (Android Studio) |
| Gradle / AGP / Kotlin | 8.14 / 8.11.1 / 2.2.20 |
| Android | compile 36, target 36, min 24; package `com.baishalya.devdesk` |
| Windows toolchain | Visual Studio Community 2026 18.6.1, Windows SDK 10.0.28000.0 |
| App version | `1.0.0+1` |

`flutter doctor -v` reported no issues. A physical Android 16 device, Windows, Chrome, and Edge were discoverable, but this audit did not claim manual device testing.

## Commands and results

| Command | Result | Duration | Important output | Classification |
| --- | --- | ---: | --- | --- |
| `git status` | Passed | <1 s | Clean at audit start | Repository |
| `git log --oneline -n 20` | Passed | <1 s | Six repository commits available; head `4fa6fb7` | Repository |
| `flutter --version` | Passed | <1 s | Flutter 3.41.9 / Dart 3.11.5 | Environment |
| `dart --version` | Passed | <1 s | Dart 3.11.5 | Environment |
| `flutter doctor -v` | Passed | ~10 s | No issues found | Environment |
| `flutter pub get` | Passed on retry | 11.2 s retry | First attempt timed out after 184 s; retry succeeded; lock hash unchanged | Transient environment/network |
| `flutter pub outdated` | Passed | ~10 s | 28 packages have versions blocked by current constraints | Dependencies |
| `dart pub deps` | Passed | ~2 s | Dependency graph resolved | Dependencies |
| `flutter pub upgrade --dry-run` | Passed | ~9 s | Would change only allowed transitive versions under current constraints; no file changed | Dependencies |
| `dart format --output=none --set-exit-if-changed .` | Passed | ~2 s | 146 files, 0 changes | Code |
| `flutter analyze` | Passed | 36 s total | No issues found; analyzer phase 8.2 s | Code |
| `flutter test` | Passed | 22.3 s | 135 tests passed | Test |
| `flutter test --coverage` | Passed | 32.2 s | 135 tests; 4,621 / 9,638 instrumented lines = 47.95% | Test |
| `flutter build apk --debug` | Passed | 86.4 s | Debug APK produced | Build |
| `flutter build apk --release` | Passed, unsafe artifact | 107.9 s | 61.4 MiB; signed with Android Debug certificate | Security/release configuration |
| `flutter build appbundle` | Passed, unsafe artifact | 26.6 s | 48.8 MiB AAB; release variant points to debug signing | Security/release configuration |
| `flutter build windows` | Passed | 121.6 s | Windows runner bundle built | Build; not functional certification |
| `flutter build web` | Passed | 131.2 s | Web output built; Wasm dry run also passed | Build; platform limits remain |

The release APK manifest was independently inspected: package `com.baishalya.devdesk`, version code/name `1` / `1.0.0`, min/target SDK 24/36, and INTERNET permission. Its signer identity is the Android debug certificate, consistent with `android/app/build.gradle.kts:30-34`.

## Test and coverage interpretation

All existing tests pass, but coverage is not risk-balanced:

| Area | Approximate line coverage | Interpretation |
| --- | ---: | --- |
| Overall | 47.95% | Useful baseline, not a release gate by itself |
| External file service | 0% | Real picker/read/overwrite safety untested |
| Git/GitHub diff services and diff provider | 0% | Prominent Diff claims can remain broken while tests pass |
| Base64/timestamp/URL/UUID providers | 0% | Utilities have some tests, state/UI paths largely do not |
| Diff page | 0.4% | UI-only/stub behavior not detected |
| Workspace executor | 5.1% | Core network body/timeout/cancellation behavior largely untested |
| Workspace provider | 8.1% | Concurrency, history, runs, and lifecycle not protected |
| API workspaces page | 30.5% | Rendering coverage is not end-to-end correctness |
| Quick API page | 43.8% | Better baseline; still lacks full network/platform edge cases |

Required missing tests are catalogued in reports 04, 05, and 13. The current suite can pass while backup replacement loses data, release artifacts are debug-signed, Diff export does nothing, and streamed responses remain unbounded.

## Direct dependency audit

Versions are the locked versions observed on 2026-07-15. “Latest” values come from `flutter pub outdated` and official package/release pages; a newer number alone is not an upgrade justification.

| Dependency | Locked → current stable | Maintenance/deprecation and risk | Recommendation / migration tests |
| --- | --- | --- | --- |
| Flutter SDK | 3.41.9 | Current installed stable; builds cleanly | Keep pinned in release CI; smoke all primary platforms before SDK movement |
| `cupertino_icons` | 1.0.9 → 1.0.9 | Stable, low risk | Keep |
| `flutter_markdown` | 0.6.23 → discontinued | Discontinued; resolvable 0.7.x exists but maintained continuation is `flutter_markdown_plus` 1.0.12 | Replace deliberately; snapshot tables/code/links/images/raw HTML and remote-resource policy |
| `flutter_riverpod` | 2.6.1 → 3.3.2 | Major changes: legacy provider imports, notifier lifecycle/error/equality behavior | Upgrade last among core packages; provider lifecycle, persistence, rebuild, and async-error tests |
| `http` | 0.13.6 → 1.6.0 | Old major API line; streaming/client semantics must be revalidated | Upgrade after executor tests; all methods, redirect/compression, cancel, connect/read timeout, streamed/large/binary responses |
| `hive` | 2.2.3 → 2.2.3 stable | Stable line is old; 4.x is prerelease. Project uses no cipher/adapters/migration | Do not chase prerelease. First design schema/migration/recovery and secret-store separation |
| `hive_flutter` | 1.1.0 → 1.1.0 stable | Same strategic concern as Hive | Keep until storage design is tested |
| `uuid` | 3.0.7 → 4.6.0 | Current v4 implementation is intended to be cryptographically strong; major package redesign | Low/medium migration after tests for format, batch, uniqueness and platform randomness |
| `diff_match_patch` | 0.4.1 → 0.4.1 | Current pub release but old/unverified publisher metadata; algorithm can be expensive | Keep provisionally; add large-input caps/benchmarks and evaluate maintained alternatives |
| `file_picker` | 11.0.2 → 11.0.2 | Current; 11.0.2 includes Android path-traversal fix | Keep; native Android/Windows dialog and content-URI tests |
| `archive` | 3.6.1 → 4.0.9 | Major 4.x stream API changes; past path/symlink security fixes are already newer than 3.3.8, but current use is ZIP-bomb-prone | Upgrade only with pre-decompression/resource-limit redesign and malicious archive tests |
| `path` | 1.9.1 → 1.9.1 | Current/low risk | Keep |
| `flutter_lints` | 6.0.0 → 6.0.0 | Current | Keep; consider targeted stricter async/resource rules separately |
| `test` | 1.30.0 → current resolved | SDK-managed compatibility | Keep SDK-resolved |
| `mockito` | 5.6.4 → current resolved | Active; generated mocks not the core risk | Keep; prefer realistic fake streaming clients for executor behavior |
| `flutter_launcher_icons` | 0.13.1 → 0.14.4 | Build-time only; older config still works | Upgrade after release asset baseline; regenerate and visually verify all densities |
| `flutter_native_splash` | 2.4.4 → 2.4.8 | Minor lag, build-time only | Low-priority isolated upgrade; regenerate and verify Android launch |

Primary references:

- Flutter Markdown continuation: https://pub.dev/packages/flutter_markdown_plus
- Riverpod 3 migration: https://riverpod.dev/docs/3.0_migration
- HTTP versions/changelog: https://pub.dev/packages/http/versions and https://pub.dev/packages/http/changelog
- Archive changelog: https://pub.dev/packages/archive/changelog
- File Picker changelog: https://pub.dev/packages/file_picker/changelog
- Hive versions: https://pub.dev/packages/hive/versions
- UUID: https://pub.dev/packages/uuid
- diff_match_patch: https://pub.dev/packages/diff_match_patch/versions

## Safe upgrade order

1. Freeze a reproducible baseline: CI format/analyze/test/coverage plus APK, AAB, Windows, and web builds.
2. Keep `file_picker` current and redesign ZIP limits; then migrate `archive` with malicious/truncated/symlink/zip-bomb fixtures.
3. Replace discontinued Markdown with explicit link/image/raw-HTML policy and golden/widget coverage.
4. Add executor tests and bounded streaming; then migrate `http` to 1.x.
5. Upgrade `uuid` and build-time icon/splash tools in isolated changes.
6. Decide Hive migration/schema/secret strategy; do not couple it to a package bump.
7. Migrate Riverpod 3 last, because provider lifecycle, legacy imports, equality, and error propagation span most features.

## Environment limitations

- No iOS/macOS build is possible on this Windows host; Linux was not configured or built.
- Native Android picker, app lifecycle, offline/DNS/TLS, and Windows read-only/network-path/file-lock workflows were not manually exercised.
- Web compilation does not prove arbitrary endpoint access because CORS and mixed-content policy are endpoint/browser dependent.
- `cmake` was not on the interactive PATH, although Flutter successfully used the Visual Studio-bundled Windows toolchain.
