# Product Improvement Backlog

This backlog preserves DevDesk's local-first identity. “Release” means the earliest appropriate train after the safety roadmap; it is not permission to start feature work before blockers.

## Essential

| Improvement | Problem solved / target user | Complexity | Privacy impact | Maintenance burden | Priority | Recommended release |
| --- | --- | ---: | --- | ---: | ---: | --- |
| Protected API secret vault/references | Prevents local/export credential leakage for API users | Large | Strong positive; key recovery/migration sensitive | High | P0 | Before public release |
| Transactional versioned backup/restore | Prevents data loss for every persistent user | Large | Positive; secret manifest required | High | P0 | Before public release |
| Production Android signing | Establishes trusted install/update chain | Medium | Neutral/positive | Medium | P0 | Before public release |
| Signed packaged Windows distribution | Provides complete trusted install/portable workflow | Medium/Large | Neutral/positive | Medium | P1 | Before Windows release |
| Bounded streamed API responses and complete cancellation | Prevents hangs/OOM/wrong calls for API users | Large | Reduces response retention | High | P1 | Before public release |
| Safe atomic external replacement | Prevents source-file corruption for editor users | Large | Neutral | Medium | P1 | Before external overwrite claim |
| Storage schema/bootstrap recovery | Prevents upgrade/corruption lockout for all users | Large | Enables safe secret migration/deletion | High | P1 | Before public release |
| Untrusted-input resource policy | Prevents regex/JSON/diff/Markdown/ZIP freezes | Large | Availability positive | Medium/High | P1 | Before public release |
| Truthful privacy/product/release copy | Gives users accurate network/storage expectations | Medium | Strong positive | Low/ongoing | P1 | Before public release |
| Honest functional Diff scope | Removes no-op/broken promises for diff users | Medium if scoped down | Reduces unnecessary network/archive risk | Low | P1 | Before public release |
| Risk-weighted regression/integration suite | Makes all safety work maintainable | Large | Positive through leak/rollback tests | High | P1 | Before release candidate |

## High-value

| Improvement | Problem solved / target user | Complexity | Privacy impact | Maintenance burden | Priority | Recommended release |
| --- | --- | ---: | --- | ---: | ---: | --- |
| cURL import/export with redacted preview | Fast terminal/docs/client interoperability | Medium | Secrets require explicit confirmation | Medium | High | First post-baseline 1.x |
| Correct URL-encoded form and multipart file requests | Common API submissions currently fail/are absent | Medium/Large | Local file/body sensitivity | Medium | High | First post-baseline 1.x |
| Request/document tabs and draft/session restore | Avoids context loss for desktop/tablet users | Medium | Persist nonsecret metadata by default | Medium | High | 1.x |
| Command palette and core shortcuts | Faster keyboard-first developer workflow | Medium | Low | Medium | High | 1.x |
| JSONPath and JSON Schema | Query/validate API payloads locally | Medium | Positive/local; resource limits required | Medium | High | 1.x |
| YAML and XML format/validate/convert | Covers common configuration/data formats | Medium | Local; parser hardening needed | Medium | High | 1.x |
| Hash/checksum and HMAC | File/text integrity verification | Medium | HMAC key must use secret handling; clear misuse copy | Medium | High | 1.x |
| Retention/paging for history/reports/snippets/vault | Controls storage, startup, and sensitive footprint | Medium/Large | Strong positive | Medium | High | 1.x |
| Accessible text modes for JSON tree and Diff | Enables screen-reader/keyboard use | Medium | Neutral | Medium | High | Before accessibility claim |
| Git-friendly filesystem workspace format | Local collaboration/versioning without cloud | Large | Keep secret refs out of Git | High | High/strategic | Later 1.x |

## Nice-to-have

| Improvement | Problem solved / target user | Complexity | Privacy impact | Maintenance burden | Priority | Recommended release |
| --- | --- | ---: | --- | ---: | ---: | --- |
| Cookie jar with visible retention controls | Stateful API sessions | Large | High sensitivity; opt-in/clear required | High | Medium | Later 1.x |
| Request chaining without arbitrary scripts | Reuse response values in collection runs | Medium | Extracted secrets need protection | Medium | Medium | Later 1.x |
| User-key JWT verification | Helps security/debug users distinguish authenticity | Large | User-provided keys remain local/protected | High | Medium | Later 1.x |
| Number-base and text/HTML escaping tools | Frequent small transforms | Small/Medium | Low | Low | Medium | Later, demand-led |
| Cron expression explainer | Debug schedules locally | Medium | Low | Medium due dialects/timezones | Medium | Later |
| Color conversion/contrast helper | Frontend utility and accessibility support | Medium | Low | Low | Medium | Later |
| QR generation | Offline transfer of text/URLs | Medium | Warn about embedded secrets/unsafe URLs | Medium | Low/medium | Later |
| SQL formatting | Common developer workflow | Medium/Large | Local; dialect/parser upkeep | High | Low/medium | Later |
| Drag/drop and recent-file integration on Windows | Faster desktop file workflows | Medium | File path/history disclosure controls | Medium | Medium | Windows 1.x |

## Experimental

| Improvement | Problem solved / target user | Complexity | Privacy impact | Maintenance burden | Priority | Recommended release |
| --- | --- | ---: | --- | ---: | ---: | --- |
| GraphQL client/introspection | Schema-centric API debugging | Large | Introspection data and network disclosure | High | Low | Experimental after REST is reliable |
| WebSocket/SSE client | Real-time API debugging | Large | Long-lived connection/message retention | High | Low | Experimental/native-first |
| Sandboxed plugin architecture | Community extensibility without core bloat | Very large | Major plugin supply-chain/permission risk | Very high | Low | Research only |
| Local-only recipe pipelines | Chain transforms like lightweight CyberChef | Large | Intermediate secret retention/share risk | High | Low | Prototype after resource policies |
| Optional portable encrypted workspace | Move local workspace safely across machines | Very large | Key derivation/recovery critical | Very high | Low | Research after vault/backup maturity |

## Rejected / not suitable now

| Improvement | Problem/target | Complexity | Privacy impact | Maintenance burden | Priority | Recommended release |
| --- | --- | ---: | --- | ---: | ---: | --- |
| Mandatory account and cloud sync | Not required by target local developer | Very large | Strong negative; creates identity/backend obligations | Very high | Rejected | None |
| Default telemetry/analytics | Product metrics without demonstrated need | Medium | Conflicts with privacy positioning | High governance burden | Rejected | None |
| Built-in remote AI processing | Unvalidated value for core utility flows | Very large | User code/secrets may leave device | Very high/costly | Rejected now | None |
| TLS interception/certificate bypass | Specialist proxy/security workflow | Very large | Dangerous trust-store and misuse surface | Very high | Rejected | None |
| Full Postman/Insomnia protocol/team parity | Scope expansion beyond focused toolbox | Extreme | Large credential/cloud/network surface | Extreme | Rejected | None |
| Broad CyberChef-like cryptographic suite | Specialist correctness users already have mature tools | Extreme | High misuse/correctness risk | Extreme | Rejected | None |
| Claiming iOS/macOS/Linux support from generated folders | No verified user problem is solved by a false badge | Medium per platform | Policy/support ambiguity | High matrix burden | Rejected until proven | Only after full platform qualification |

## Sequencing principle

Trust and recoverability are the product features that unlock everything else. Do not add protocols, utilities, plugins, or cloud concepts until signing, secrets, storage, files, backup, API lifecycle, performance limits, accessibility, and regression gates are demonstrably safe.
