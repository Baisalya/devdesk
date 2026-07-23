# Security and Privacy

## Default posture

DevDesk is local-first, has no account requirement, analytics, telemetry, advertising SDK, or cloud synchronization, and does not start network activity merely by opening local Markdown, JSON, OpenAPI, Git, or utility screens. The first-run privacy gate requires acceptance before the main app can be used. The user can reopen the policy from Settings.

Network access occurs only for a user-started API request, a supported GitHub fetch, or a future provider explicitly enabled by the user. Remote Markdown images remain blocked.

## Secrets

API secret values are stored in a protected overlay: Android Keystore-backed encryption on Android and DPAPI on Windows. Ordinary Hive records, portable API exports, backups, diagnostics, and common clipboard flows exclude or redact secret values. Redaction is defense in depth, not a substitute for reviewing exported content.

AI is disabled by default. Enabling a provider does not imply full-workspace disclosure: a disclosure scope must also be selected. Context marked as potentially secret is redacted unless the user explicitly allows secret values. AI output is a proposal and requires review, source fingerprints, and confirmation before an apply layer may write.

MCP servers are disabled until enabled. Read-only tools may run only on enabled servers. Workspace writes and external side effects require explicit per-call confirmation.

## Files and processes

Workspace reads and indexes have count and byte limits, reject traversal, and avoid symlinks by default. Windows direct overwrite uses same-directory staging, identity checks, verification, and native atomic replacement. Git uses direct processes, bounded output, timeouts, canonical roots, `--` path separation, and stale-snapshot guards.

## Network controls

The API client accepts HTTP and HTTPS destinations selected by the user. Credentials in URLs are rejected. Response buffering is bounded and has connect, total, and read-idle deadlines. Certificate validation is never bypassed. Custom CA/client-certificate and proxy controls are not available in this release.

## Retention and deletion

Removing a registered developer workspace removes only DevDesk metadata and never deletes the selected folder. App data can be cleared through the existing storage controls. Backups are versioned, previewed, staged, and recoverable; protected secrets are excluded.

The store-hostable policy is `docs/privacy-policy.html`. Publish it at a stable HTTPS URL and use that exact URL in Play Console before release. This document is technical guidance and not legal advice.
