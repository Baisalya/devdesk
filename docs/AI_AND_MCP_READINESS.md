# AI and MCP Readiness

DevDesk contains extension contracts, policy gates, and tests—not an enabled AI product or bundled MCP server.

## AI boundary

`AiProviderSettings` defaults to disabled with no disclosure scope. Local and remote providers can later implement `AiAssistant`. Every request envelope carries the exact selected context and approved disclosure scope. Potentially secret context is redacted unless separately allowed.

AI output uses `AiChangeProposal`: a summary plus workspace-relative replacements and expected source fingerprints. `AiProposalGate` refuses unconfirmed or unversioned changes. A future apply adapter must still re-check capabilities and fingerprints and use the existing safe workspace write boundary.

Before enabling a provider, add:

- provider-specific authentication in the protected secret store;
- clear endpoint, retention, training, and jurisdiction disclosure;
- request/response size and timeout limits;
- cancellation and offline status;
- a diff-based proposal review UI;
- provider contract, adversarial prompt, secret-leak, and failure tests.

## MCP boundary

An `McpServerAdapter` declares its server ID and tools. Each tool declares read-only, workspace-write, or external-side-effect access. Servers are hidden and unusable until explicitly enabled. Write/external tools require confirmation on each call.

Before enabling external MCP servers, add transport authentication, server identity pinning where applicable, schema validation, bounded results, cancellation, audit events without payload secrets, per-workspace grants, revocation, and a visible tool-call review UI.

These interfaces intentionally prevent an eventual provider from being embedded in widgets or receiving implicit access to the whole workspace.
