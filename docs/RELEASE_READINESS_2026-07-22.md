# DevDesk 1.0.0 Release Readiness

Assessment date: 22 July 2026

## Outcome

The codebase is ready for owner-led signing and final release packaging. A current unsigned Windows portable verification artifact is built. Android compiles and passes the debug build, while the production AAB remains intentionally blocked until the owner supplies the permanent release-signing identity.

Commerce remains disabled. No purchase button is available, no billing platform is queried, and every capability currently shipped remains on the Free plan.

## Automated evidence

- `flutter analyze`: pass, zero issues.
- `flutter test`: pass, 333 tests.
- Permanent responsive matrix: pass, 114 page/viewport cases.
- Matrix coverage: 19 pages at 280x480, 320x568, 568x320, 500x400 and 900x600, plus every page at 320x568 with 200% text.
- Theme coverage: six palettes in Light and Dark, persistence/migration, standard/high contrast and comfortable/compact density.
- Commerce guard coverage: current capabilities Free, certification switch off, disabled adapter cannot purchase.
- Privacy coverage: versioned persistence, policy-update re-acknowledgement, Clear All Data reset, fail-closed storage behavior, global-shortcut blocking, Settings access, and 280x480 at 200% text.
- Static privacy HTML: 12 sections, no JavaScript, no horizontal overflow at 360px or 1280px, and correct language/description/contact links.
- Windows x64 release build: pass.
- Android debug APK build: pass.
- Android release AAB guard: pass by rejecting a release build without production signing credentials.

## Artifacts

### Windows portable verification artifact

`build/release/devdesk-windows-x64-1.0.0.zip`

SHA-256: `BE1970A31290CB67A90AE0BB6EF79C3495FC98B35B5FE2453917900DDCA8148C`

The ZIP includes the executable, Flutter runtime, native plugins and current compiled Dart data. Do not distribute `devdesk.exe` by itself. This ZIP is unsigned and is not a public release artifact.

### Android verification artifact

`build/app/outputs/flutter-apk/app-debug.apk`

SHA-256: `83EADDD771614C86292D7EBB452C4F2234DB827AFDC3FC1B78086C2E18182F8C`

This APK is for device QA only and must not be uploaded as a production release.

## Required owner actions before public submission

1. Android: provide the permanent upload keystore and the four signing values through ignored `key.properties` or `DEVDESK_ANDROID_*` CI secrets.
2. Build and archive `flutter build appbundle --release`, then upload it to a closed Play test track before production.
3. Windows Store, if desired: reserve/associate the Partner Center identity and package the app as an identity-bearing MSIX. The portable ZIP does not provide Store commerce identity.
4. Run physical-device/manual accessibility QA: Android TalkBack, IME, largest font/display scaling, split-screen/freeform; Windows keyboard-only, high contrast, NVDA and multiple DPI levels.
5. Publish `docs/privacy-policy.html` at a public HTTPS URL using `docs/release/PRIVACY_POLICY_PUBLISHING.md`, then complete the Play privacy field, Data safety form, support contact, content rating, target audience, and listing assets.
6. Capture final screenshots from the signed/package-installed builds.

The complete checklist, including future billing prerequisites, is in `docs/COMMERCE_AND_RELEASE_CHECKLIST.md`.
