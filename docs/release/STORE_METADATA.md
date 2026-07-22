# Store and Public Metadata Draft

## Product name

DevDesk

## Short description

Offline-first developer toolbox for Markdown, JSON, API testing, diffs, tokens, snippets, and everyday utilities.

## Full-description boundaries

DevDesk processes most content locally and includes no account, analytics, telemetry, cloud sync, remote AI, or DevDesk backend. Network access occurs only for user-initiated API requests, supported GitHub fetches, link checks, and explicit store/repository actions. API requests go directly to the endpoint selected by the user.

Protected API secret persistence is available on Android and Windows. Web secrets are session-only. Backups exclude protected secrets and use validation plus rollback. Remote Markdown images are blocked.

Do not state that every feature is completely offline, that API destinations receive no data, that JWT signatures are verified, that arbitrary Git repositories are supported, or that iOS/macOS/Linux are supported releases.

## Android Data Safety draft

- DevDesk-operated collection/service: none.
- Analytics, advertising, accounts, remote AI, cloud sync, and payment processing: none.
- User-provided API data is transmitted directly to endpoints selected by the user. Google Play defines off-device transmission broadly as collection, while a transfer based on a specific user-initiated action may be excluded from the form's sharing classification. Review the exact data types supported by the final API Tester rather than submitting this draft as a blanket "no collection" answer.
- GitHub fetches and link checks transmit the chosen URL plus ordinary connection information to the selected destination.
- Analytics/advertising: none.
- Account creation: none.
- Deletion: Clear Data and individual record deletion.

The static privacy page is ready at `docs/privacy-policy.html`; follow `docs/release/PRIVACY_POLICY_PUBLISHING.md` to deploy and verify its public URL. Final Play Console answers, deployed privacy-policy URL, support email, screenshots, feature graphic, content rating, target audience, and signing fingerprints require release-owner input and review on the final artifact.
