# DevDesk Privacy Notice

**Updated: 15 July 2026**

DevDesk is an offline-first developer toolbox. It has no account system, analytics, telemetry, advertising SDK, cloud synchronization service, or DevDesk-operated backend.

## Data kept on the device

DevDesk can store locally entered Markdown, notes, snippets, preferences, API workspace metadata, sanitized API history, reports, and vault content. Ordinary application records use Hive in the app's local data directory.

API credentials and secret values are separated from ordinary workspace records when the platform provides an appropriate boundary:

- Android: encrypted with a key held by Android Keystore.
- Windows: protected with Windows DPAPI for the current user.
- Web: no equivalent protected persistent secret store is claimed; secrets are session-only and are not saved.

Local device administrators, malware running as the user, screen capture, clipboard managers, and a compromised operating system remain outside this protection model.

## User-initiated network activity

DevDesk uses the network only for an action the user starts:

- API Tester sends the prepared request to the URL chosen by the user.
- Supported GitHub file/repository fetches contact GitHub endpoints selected by the user.

Those destination services receive the normal network information needed to serve the request, such as IP address, request URL, headers, and body. DevDesk does not proxy these requests through a DevDesk server.

Remote images in Markdown are blocked. The app does not silently fetch tracking pixels or other remote Markdown resources.

## API data and history

Request URLs, headers, bodies, cookies, responses, and extracted values can contain sensitive information. DevDesk applies conservative redaction before portable history, reports, snippets generated from requests, clipboard output, collection export, and backup export. Protected secret values are excluded from backups by default.

Redaction is defensive, not a guarantee that arbitrary confidential text can always be recognized. Review every export before sharing it.

## External files and backups

Files are read only after the user selects them through the platform picker. Android uses document URIs and does not request broad storage access. Windows uses file paths selected by the user and applies guarded atomic replacement only to supported local files.

Backup import validates type, version, schema versions, depth, sizes, and record counts before mutation. A persistent rollback journal is used so interrupted or failed imports can restore the prior local state. Backup files remain wherever the user saves them and are not uploaded by DevDesk.

## Clipboard and operating-system features

Explicit copy actions place redacted content in the operating-system clipboard. Clipboard history, synchronized clipboard features, screen readers, screenshots, backups made by the operating system, and other software on the device are controlled by the operating system and user configuration.

Android application backup/data extraction is disabled for DevDesk's private data. Windows local data follows the user's Windows profile and backup policy.

## Web limitations

Browser CORS, mixed-content rules, storage quotas, private browsing, clipboard permission, and browser data clearing can limit or remove functionality. DevDesk does not claim the web build has the same file overwrite or protected-secret guarantees as Android and Windows.

## Deletion and retention

Users can delete individual records or use Clear Data. Clear Data cancels active API work, clears all known local boxes and protected secrets, and invalidates application providers. API history and reports are bounded by application retention limits.

## Contact

Privacy questions and defects can be filed through the repository issue tracker. Do not include real credentials, tokens, private request bodies, or personal data in a public report. Security-sensitive reports should follow `SECURITY.md`.
