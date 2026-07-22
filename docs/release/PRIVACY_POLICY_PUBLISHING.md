# Privacy Policy Publishing Guide

The release-ready static policy is [`docs/privacy-policy.html`](../privacy-policy.html). It contains no JavaScript, adapts to mobile and desktop screens, and remains readable when scripts are disabled.

## Publish with GitHub Pages

1. Push the final reviewed policy to the public `Baisalya/devdesk` repository.
2. In repository **Settings → Pages**, choose **Deploy from a branch**.
3. Select the release branch (normally `main`) and the `/docs` folder, then save.
4. After deployment, verify this expected project-site URL in a signed-out/private browser window:

   `https://baisalya.github.io/devdesk/privacy-policy.html`

5. Confirm the page loads without authentication, JavaScript, a geographic restriction, or a download prompt.
6. Enter that exact HTTPS URL in Play Console under **Policy and programs → App content → Privacy policy**.
7. Use the same URL for the Microsoft Store privacy-policy field if that store listing is created.

The URL is not release-ready merely because the HTML exists in the repository. It must return a successful public web response after Pages (or another static host) is enabled.

## Keep all copies aligned

The same policy is represented in three places:

- `lib/features/privacy/domain/privacy_policy.dart` — in-app gate and Settings page.
- `PRIVACY.md` — repository-readable policy.
- `docs/privacy-policy.html` — public store-listing page.

For a material policy change:

1. Update all three copies.
2. Change the effective date and `DevDeskPrivacyPolicy.version`.
3. Confirm existing users see the acknowledgement gate again.
4. Update the Play Console Data safety answers when any collection, sharing, SDK, permission, retention, or security practice changes.

## Release-owner checks

- Confirm that **Baisalya** exactly matches the developer or entity name shown on the final store listing. If it does not, update all policy copies before publishing.
- Add a monitored support email to the store listing. The current policy provides the public issue tracker as its privacy-inquiry mechanism and private security advisories for sensitive reports.
- Review the final Android dependency graph and merged manifest before answering the Data safety form; third-party SDK behavior is the publisher's responsibility.
- DevDesk has no account system, so Google Play's account-deletion URL requirement does not apply to the current build. Revisit this before enabling future subscriptions or accounts.
- User-selected API destinations can receive user-provided request content. Keep this disclosure even though the transfer is user-initiated and is not proxied through a DevDesk server.

This guide is release engineering guidance, not legal advice. The publisher remains responsible for applicable privacy laws and final store declarations.
