# Third-Party Notices

DevDesk uses Flutter/Dart packages whose copyright and license terms remain with their respective authors. Direct dependencies are declared in `pubspec.yaml`; the exact resolved dependency graph is in `pubspec.lock` after `flutter pub get`.

The release process must generate a complete notice bundle from the resolved package cache:

```bash
dart run tool/release/generate_third_party_notices.dart
```

The generator reads `.dart_tool/package_config.json`, copies each resolved package's LICENSE/NOTICE text, and fails if a package has no discoverable license file. Review and commit the generated release notice beside the final lockfile before public distribution.

A generated notice is intentionally not included in this source snapshot because dependency resolution could not be run in the remediation environment. This file is therefore a release blocker record, not a claim that third-party notice review is complete.
