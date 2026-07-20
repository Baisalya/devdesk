#!/usr/bin/env bash
set -euo pipefail

command -v flutter >/dev/null || { echo 'Flutter SDK is required.' >&2; exit 127; }
command -v dart >/dev/null || { echo 'Dart SDK is required.' >&2; exit 127; }

git status --short
flutter --version
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test --coverage
flutter pub outdated || true
dart pub deps
flutter build apk --debug
flutter build web

cat <<'NOTICE'
Release APK/AAB builds are intentionally not run by this generic verification
script. Use a protected release job with the DEVDESK_ANDROID_* signing values.
Windows builds must run on Windows.
NOTICE
