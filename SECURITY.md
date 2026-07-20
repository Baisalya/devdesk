# Security Policy

## Supported versions

Only the latest source revision on the active release-remediation branch is under security review. No public binary is declared supported until the release checklist is completed on signed artifacts.

## Reporting a vulnerability

Use a private repository security advisory when available. Do not open a public issue containing credentials, tokens, private URLs, personal data, exploit payloads against third parties, or proprietary request/response content.

Include the affected platform, DevDesk version/commit, reproduction steps using disposable canary data, expected result, actual result, and whether local data or external endpoints are affected.

## Scope

In scope: secret persistence/export, backup rollback, archive/input handling, file replacement, API cancellation/limits/redaction, platform bridges, and release signing configuration.

Out of scope: vulnerabilities that require an already-compromised operating-system account, clipboard manager, administrator, debugger, or physical extraction beyond the documented threat model; attacks against endpoints the user chooses to test; and requests to bypass TLS or certificate validation.

## Response

Reports are triaged before disclosure. A fix is not considered complete until a regression test or reproducible platform verification is recorded. No guaranteed response time is claimed until a formal support channel is published.
