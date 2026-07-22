# DevDesk Commerce and Release Checklist

Status: **commerce disabled; Free release technically ready except for the owner's Android production signing credentials.**

This document is the activation gate for future subscriptions. The current build cannot query products, show a purchase button, collect payment, or grant a client-only entitlement. `CommerceConfig.implementationReady` remains `false` until every mandatory item below is signed off.

## Product contract

### Free forever for the current product

- All current developer tools: JSON, regex, Base64, URL, timestamp, UUID, JWT, diff, README, snippets and quick API testing.
- Local API workspaces, collections, environments, history and local runner reports.
- Local Markdown editor and vault.
- Local files, import/export, redacted backup and restore.
- DevDesk Ocean, Terminal Matrix, Neon Violet, Ember Console, Circuit Teal and Graphite Mono in System, Light and Dark modes.
- High contrast, accessibility support and comfortable/compact density.

Existing capabilities must not be reclassified as Pro in a later release.

### Future subscription candidates

Subscriptions must provide continuing value, not merely unlock a static local feature. The initial Future Pro scope is:

- End-to-end encrypted cloud sync and cross-device workspace continuity.
- Team workspaces, sharing and permissions.
- Scheduled cloud API runs and service-backed notifications.
- Extended encrypted cloud history and recovery.
- A hosted custom-theme library or another service with ongoing maintenance.

The custom theme designer by itself should be a one-time purchase or remain free; it can only be part of a subscription when paired with an ongoing hosted service. Final monthly/annual prices, trial rules, taxes and regional availability are product-owner decisions and must be identical in value across Android and Windows.

## Android Free release gate

- [x] Application ID is `com.baishalya.devdesk`.
- [x] Release builds reject debug signing.
- [ ] Create or select the permanent production upload key.
- [ ] Store `android/key.properties` outside source control, or provide all four `DEVDESK_ANDROID_*` CI secrets.
- [ ] Enroll in Play App Signing and securely back up the upload key and recovery information.
- [ ] Build `flutter build appbundle --release` and archive the signed AAB checksum.
- [ ] Complete Play Console app content, privacy policy, data safety, content rating, countries, support contact and closed testing.
- [ ] Test install/upgrade from the Play test track on at least one small phone, tablet or freeform window, and Android dark/high-contrast settings.

Never generate a replacement signing identity during an ordinary build: changing this key can prevent future updates to the published app.

## Windows Free release gate

- [x] `flutter build windows --release` succeeds.
- [ ] Choose the distribution identity: Microsoft Store MSIX is required before Microsoft Store add-ons can be sold.
- [ ] Reserve the product name and associate the package identity in Partner Center.
- [ ] Configure publisher identity, signing certificate/Store association, architecture and installer behavior.
- [ ] Test install, update, uninstall, file-open flows and settings persistence from the packaged build—not only the portable runner directory.
- [ ] Complete Store listing, privacy URL, age rating, support contact and certification submission.

The current portable Windows ZIP is suitable for free direct distribution, but it cannot be treated as a Microsoft Store commerce identity.

## Google Play subscription activation gate

- [ ] Implement and test the native Google Play Billing channel or replace it with a maintained Flutter integration.
- [ ] Create monthly and annual subscription products in Play Console, including base plans and regional prices.
- [ ] Acknowledge purchases and handle pending, cancelled, expired, paused, grace-period and account-hold states.
- [ ] Deploy server-side purchase-token verification using the Google Play Developer API.
- [ ] Process Real-time Developer Notifications and make entitlement updates idempotent.
- [ ] Test new purchase, restore, renewal, cancellation, refund, upgrade/downgrade and offline behavior with Play license testers.
- [ ] Supply subscription management and cancellation links from the app.

Primary references: [Flutter in-app purchase guidance](https://docs.flutter.dev/cookbook/plugins/in-app-purchases), [Google Play Billing integration](https://developer.android.com/google/play/billing/integrate), [secure backend processing](https://developer.android.com/google/play/billing/security), [subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions), and [Google Play subscription policy](https://support.google.com/googleplay/android-developer/answer/9900533).

## Microsoft Store subscription activation gate

- [ ] Package DevDesk as an identity-associated MSIX and validate Store flight installation.
- [ ] Create matching monthly/annual subscription add-ons in Partner Center.
- [ ] Implement the Microsoft Store purchase channel with the packaged app identity.
- [ ] Deploy server-side receipt/entitlement validation and define cross-platform account linking.
- [ ] Handle cancellation, refund, expiration, offline grace and Store-service outages.
- [ ] Test purchase and restore from a private Store flight on Windows 10 and Windows 11.

Primary references: [Microsoft Store add-ons and subscriptions](https://learn.microsoft.com/windows/uwp/monetize/enable-subscription-add-ons-for-your-app), [in-app purchases](https://learn.microsoft.com/windows/uwp/monetize/in-app-purchases-and-trials), and [Microsoft Store Services SDK](https://learn.microsoft.com/windows/apps/windows-app-sdk/microsoft-store-services-sdk/).

## Shared entitlement backend gate

- [ ] Define a privacy-preserving DevDesk account and recovery model; local-only users must remain supported.
- [ ] Map Google and Microsoft transactions to one server entitlement without trusting client claims.
- [ ] Encrypt data in transit and at rest; separate encryption keys from authentication and billing data.
- [ ] Add idempotency, replay protection, audit records, least-privilege credentials and secret rotation.
- [ ] Publish privacy, retention, deletion, refund, support and incident-response policies.
- [ ] Add monitoring for failed verification, webhook lag and entitlement divergence.
- [ ] Complete threat modeling and an independent security review.

## Activation procedure

1. Complete every platform and backend checkbox.
2. Add production adapters and a real `PurchaseVerificationGateway`; client tokens alone must never call `applyVerified`.
3. Add automated sandbox/store-flight tests and backend contract tests.
4. Change `CommerceConfig.implementationReady` to `true` only in a reviewed commerce release.
5. Supply all product IDs, the HTTPS verification endpoint and `DEVDESK_MONETIZATION_ENABLED=true` at build time.
6. Verify the UI shows localized Store prices, complete terms, restore and management actions.
7. Roll out behind a server kill switch, monitor a small percentage, then expand.

If any requirement is missing, the app must remain on the Free plan and display no purchase action.
