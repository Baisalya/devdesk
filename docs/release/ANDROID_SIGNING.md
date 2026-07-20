# Android Signing Runbook

DevDesk release APK/AAB tasks fail closed unless all four signing values are supplied. Debug signing is never selected by the release build type.

## Local configuration

Copy `android/key.properties.example` to `android/key.properties`, keep it outside source control, and set:

- `storeFile`
- `storePassword`
- `keyAlias`
- `keyPassword`

Alternatively use environment variables:

- `DEVDESK_ANDROID_STORE_FILE`
- `DEVDESK_ANDROID_STORE_PASSWORD`
- `DEVDESK_ANDROID_KEY_ALIAS`
- `DEVDESK_ANDROID_KEY_PASSWORD`

The keystore must be created, backed up, and controlled by the release owner. This repository does not create a fake production key.

## Build and verify

```bash
flutter clean
flutter pub get
flutter build apk --release
flutter build appbundle
```

Then independently inspect the APK signer/certificate, confirm the manifest is not debuggable, record SHA-256, and test clean install plus upgrade from the previous signed internal-track build. Decide and document Google Play App Signing/upload-key recovery before first production upload.

## Required external evidence

- Keystore custody and recovery owner
- Upload certificate SHA-256 fingerprint
- Play App Signing decision and app-signing fingerprint
- Internal-track install/upgrade result
- Immutable APK/AAB hashes

Without these external credentials and checks, signing status is **configured but not completed**.
