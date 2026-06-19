# Release Checklist

Use this checklist to prepare DevDesk for a production release on Google Play. Each item is important for ensuring that the application meets quality, privacy and compliance standards.

## Code and quality

- [ ] **Feature completeness**: confirm all advertised tools (dashboard, Markdown editor, README generator, JSON viewer, API tester, JWT decoder, regex tester, Base64 tool, URL encoder/decoder, timestamp converter, UUID generator, diff checker, snippets and settings) work offline and provide meaningful feedback on invalid input.
- [ ] **Unit tests**: run `flutter test` and ensure all tests pass. Add or update tests if new logic is introduced.
- [ ] **Widget tests**: ensure critical UI behaviour (search, theme switching, JSON formatting, API requests, note CRUD, etc.) is covered and passes.
- [ ] **Integration tests**: simulate real‑world flows (saving a note, formatting JSON, making an API request, exporting data) and ensure correct results.
- [ ] **Linting and formatting**: run `flutter analyze` and `dart format .` to fix any issues and maintain code style.
- [ ] **Remove dead code**: ensure there is no unused or obsolete code, commented blocks or TODO placeholders in production features.
- [ ] **Dependencies**: verify that all dependencies in `pubspec.yaml` are up to date and do not introduce breaking changes. Avoid adding unnecessary packages.

## Build configuration

- [ ] **App name and package name**: confirm that `android/app/src/main/AndroidManifest.xml` defines the correct application ID (`com.example.devdesk` or your chosen ID) and that the displayed app name matches “DevDesk” (or “DevKit Offline”).
- [ ] **Icon assets**: supply a proper app icon in `android/app/src/main/res` or create one with Flutter’s `flutter_launcher_icons` package. Ensure all required densities (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi) are provided.
- [ ] **Permissions**: include only necessary permissions in the Android manifest. At minimum, add `INTERNET` for the API tester and avoid requesting storage or personal data permissions.
- [ ] **Versioning**: update `version` in `pubspec.yaml` with a new version number and build number for each release.
- [ ] **Proguard rules**: if using obfuscation, add rules to keep necessary classes (e.g. Hive adapters) from being stripped.

## Play Store listing

- [ ] **Title and description**: write a clear app title and short description. The full description should outline the main features and emphasize offline privacy. Avoid misleading or deceptive claims.
- [ ] **Screenshots**: prepare high‑quality screenshots for different screen sizes (phone and tablet) showing the dashboard, API tester, JSON formatter and other tools.
- [ ] **Feature graphic (optional)**: create a 1024×500px feature graphic for the Play Store listing.
- [ ] **Privacy policy**: provide a link to the privacy policy (see `PRIVACY.md`). State clearly that no user data is sent to any server and all data stays on the device.
- [ ] **Content rating**: complete the Play Console content rating questionnaire. DevDesk has no user‑generated content or sensitive data.

## Additional steps

- [ ] **Backup and restore**: test export/import of local data to ensure that users can migrate notes and history between devices.
- [ ] **Crash resilience**: attempt to paste extremely large JSON or malformed content into each tool and confirm that the app shows a useful error instead of crashing.
- [ ] **Security**: confirm that sensitive tokens (JWT, API keys, auth headers) are never logged to console or persisted unless the user explicitly opts in. Warn users before saving secrets.
- [ ] **Accessibility**: navigate the app using TalkBack/VoiceOver. Ensure that buttons are labelled, text fields have hints and dark mode has good contrast.
- [ ] **Third‑party audits**: if distributing widely, consider a security audit of the codebase and dependencies.

Once everything on this list is checked and tested, you can proceed to build a release APK or AAB with `flutter build appbundle` and upload it through the Google Play Console. Monitor crash reports and feedback after release and plan maintenance updates accordingly.
## Cross-platform external file release checks

- [x] Dashboard exposes an Open File action.
- [x] Markdown/README, JSON, text/code, DevDesk backup, and API collection files are detected locally.
- [x] Android uses user-selected files without broad storage permission or `MANAGE_EXTERNAL_STORAGE`.
- [x] Windows supports file open/save dialogs and a guarded minimum window size.
- [x] External `.env` files show a secrets warning.
- [x] Backups show a preview and support replace/merge before import.
- [x] API collection imports warn about sensitive headers and default to excluding secrets.
