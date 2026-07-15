# Manual Test Cases

**Audit execution note:** Automated tests/builds were run, but no claim is made that these manual/device cases passed. “Not run” cases must be executed against the final signed release candidate. “Known failure/risk” is based on traced production code and must be re-run after remediation. Never use real credentials; use disposable canary values.

## Startup, dashboard, and lifecycle

| Test ID | Platform | Preconditions | Steps | Expected result | Actual result | Status | Severity when failed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DD-MAN-001 | All | Empty app data | Cold launch; navigate dashboard | Recovery-safe startup; all tools visible; no error | Normal startup covered indirectly by green widget suite; no device run | Not run | P1 |
| DD-MAN-002 | All | Fault-injected Hive init denial/corruption | Launch | Recovery UI offers retry/export/reset; no crash | Code awaits storage before UI | Known failure: DD-STORAGE-001 | P1 |
| DD-MAN-003 | All | Saved light/dark/system modes | Restart after each selection | Correct theme without flash; errors recoverable | Theme tests passed; native restart not run | Partial | P2 |
| DD-MAN-004 | Android/Windows | Normal data | Search mixed case/whitespace/name/description; clear query | Correct normalized results and empty state | Dashboard automated tests passed | Automated pass; manual not run | P2 |
| DD-MAN-005 | All | Normal data | Favorite/unfavorite; open >8 tools; restart | Favorite/recent order persists and only known routes display | Provider/widget tests passed; corrupt favorite case unrun | Partial | P2 |
| DD-MAN-006 | Windows/Web | Keyboard only | Traverse dashboard, search, open, return | Deterministic focus and visible indicator; no mouse required | No dedicated command/keyboard validation | Not run: DD-UI-001 | P2 |
| DD-MAN-007 | All | Each feature open with pending async work | Navigate away/reopen repeatedly | No stale state, exception, leak, or late snackbar | Not covered end-to-end | Not run | P1 |

## External files, Markdown, Vault, and README

| Test ID | Platform | Preconditions | Steps | Expected result | Actual result | Status | Severity when failed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DD-MAN-010 | Android | Files from Downloads/cloud/document providers | Open supported Markdown/JSON/text/code via system picker | Correct dispatch without broad permission; cancel is harmless | Manifest/picker code verified; device flow not run | Not run | P1 |
| DD-MAN-011 | Windows | UTF-8, BOM, UTF-16 LE/BE, LF/CRLF fixtures | Open, edit, Save As, compare bytes | Supported encodings preserved or conversion explicitly confirmed | Strict UTF-8/direct UTF-8 design | Known limitation: DD-FILE-002 | P2 |
| DD-MAN-012 | Windows | Read-only, locked, deleted, renamed, symlink, network, long path | Attempt overwrite original | Original intact; actionable recovery/Save As | Direct `writeAsString` path | Known failure/risk: DD-FILE-001 | P1 |
| DD-MAN-013 | Windows | Faultable filesystem | Kill/fill disk at temp write/flush/replace phases | Original always intact; recoverable temp identified | No temp/atomic workflow exists | Known failure: DD-FILE-001 | P0 |
| DD-MAN-014 | All | Empty, binary-renamed-text, 5 MiB, >5 MiB files | Open each | Empty works; binary fails safely; limit enforced cumulatively | Size/strict UTF-8 code and utility tests exist | Partial | P1 |
| DD-MAN-015 | Android/Windows/Web | New Markdown | Edit, toolbar, preview tables/code/malformed text, copy, internal save, Save As | Correct content and stable layout | Markdown widget/tests passed for ordinary cases | Partial; platform run needed | P2 |
| DD-MAN-016 | All | Dirty Markdown/text | Back, Escape/window close, Android app switch/kill | Confirm or draft recovery; no silent loss | In-app `PopScope` only | Known gap: DD-FILE-003 | P2 |
| DD-MAN-017 | All | 100 KiB/1 MiB/5 MiB Markdown; rapid typing | Edit/scroll/preview | Responsive within budget; cancel/disable preview option | No benchmark; live full preview | Not run: DD-PERF-001 | P1 |
| DD-MAN-018 | All | Markdown with remote image/link and unsafe schemes | Open offline and with interception; activate links | No automatic network; explicit safe consent; blocked unsafe schemes | No explicit renderer policy | Not run: DD-PRIV-002 | P1 |
| DD-MAN-019 | All | Vault with wiki links/tags/versions | CRUD, rename, backlink, restore, restart | Correct links/versions without lost updates | Utility/widget coverage partial | Partial | P1 |
| DD-MAN-020 | All | Malicious/truncated/high-ratio/many-entry/traversal/symlink ZIP | Import vault | Reject before excessive allocation; no mutation | Whole decode precedes expanded checks | Known risk: DD-SEC-002 | P1 |
| DD-MAN-021 | All | README fields empty/special Markdown/URLs | Generate, edit, copy, save/vault/export | Required validation, valid intended Markdown, conflict prompt | Generator tests passed for core flow; escaping/conflict unrun | Partial | P2 |

## JSON and focused utilities

| Test ID | Platform | Preconditions | Steps | Expected result | Actual result | Status | Severity when failed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DD-MAN-030 | All | Valid/invalid/Unicode JSON | Validate, pretty, minify, tree | Correct output and line/column; Unicode preserved | JSON utility/widget tests passed | Automated pass; manual not run | P2 |
| DD-MAN-031 | All | Duplicate keys, huge integers, extreme exponent | Format/tree on native and web | Limitations disclosed; no silent security claim | Duplicate keys collapse; web precision unverified | Not run | P2 |
| DD-MAN-032 | All | Deep nesting and 1k/100k/1m nodes | Validate/tree/scroll/cancel | Enforced limits, responsive lazy tree, graceful error | No depth/node/worker limits | Known risk: DD-PERF-001 | P1 |
| DD-MAN-033 | All | Valid 3-part JWT incl Unicode/exp/nbf/iat/alg none; invalid 2/4 parts | Decode | Exact structure validation; UTC states; prominent no-signature warning; alg-none warning | Core tests pass; visible warning confirmed; parser accepts 2+ parts | Partial | P2 |
| DD-MAN-034 | All | Invalid, multiline, Unicode, zero-width regex | Execute and inspect highlights | Correct matches/no loops; errors actionable | Regex tests cover ordinary behavior | Partial | P2 |
| DD-MAN-035 | All | Catastrophic regex and large input | Run then cancel/navigate | Hard timeout/cancel; UI responsive | Synchronous uncapped execution | Known failure/risk: DD-PERF-001 | P1 |
| DD-MAN-036 | All | ASCII/Unicode/invalid/padded/unpadded/Base64URL/binary | Encode/decode | Standard behavior correct; unsupported modes clearly identified | Standard UTF-8 utility tests pass; URL/binary absent | Partial | P2 |
| DD-MAN-037 | All | Query value, full URL, spaces, `+`, Unicode, `%`, malformed/double encoding | Encode/decode | Explicit component semantics; errors safe | Component utility tests pass; form/full URL not supported | Partial | P2 |
| DD-MAN-038 | All | seconds/millis, negative, 12/13 digits, far dates, DST, timezone change | Convert both directions | Explicit unit, correct UTC/local/DST, no digit ambiguity | Length heuristic confirmed | Known limitation | P2 |
| DD-MAN-039 | All | Counts 1, 1000, 1001 | Generate/copy/check format/duplicates/time | v4 format, bounded batch, no duplicate in set, responsive | Utility tests pass core bounds | Partial | P3 |

## Diff, snippets, and settings

| Test ID | Platform | Preconditions | Steps | Expected result | Actual result | Status | Severity when failed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DD-MAN-040 | All | Insert/delete/unchanged/Unicode/LF-vs-CRLF text | Compare modes/options | Accurate literal/normalized differences clearly distinguished | Diff utility tests pass normal cases | Partial | P2 |
| DD-MAN-041 | Windows/Android | Two files and two ZIPs | Use Files tab | Correct bounded comparison or action absent | UI does not wire ZIP comparison | Known failure: DD-ARCH-001 | P1 |
| DD-MAN-042 | Windows | Git repo with branches/changes | Use Git action | Select repo/revisions and show result, or no advertised action | Only `git --version` probe | Known failure: DD-ARCH-001 | P1 |
| DD-MAN-043 | All | GitHub repo and blob URLs; offline/large content | Compare/fetch/cancel | Supported URL works with timeout/cap; root repo flow honest | Root URL cannot fetch file; ZIP UI says unimplemented | Known failure: DD-ARCH-001 | P1 |
| DD-MAN-044 | All | Completed text diff | Export each offered format; restart | Real file/clipboard output; persistent history if claimed | Export is snackbar; history memory-only | Known failure: DD-ARCH-001 | P1 |
| DD-MAN-045 | All | Empty/normal/large snippets, duplicate/concurrent operations | CRUD/search/tags/copy/restart | Deterministic IDs/order; error/retry; no lost updates | CRUD tests pass; concurrency/corruption absent | Partial | P1 |
| DD-MAN-046 | All | Corrupt/legacy snippet map | Open snippets | Quarantine bad record and offer recovery | Strict casts/unhandled load | Known risk: DD-STORAGE-001 | P1 |
| DD-MAN-047 | All | Data in every box and feature open | Confirm Clear Data; inspect UI/restart/boxes | All state gone immediately/durably; pending saves canceled | Boxes cleared but providers not invalidated | Known gap: DD-STORAGE-002 | P1 |

## API tester

| Test ID | Platform | Preconditions | Steps | Expected result | Actual result | Status | Severity when failed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DD-MAN-050 | Native | Local deterministic test server | Send GET/POST/PUT/PATCH/DELETE/HEAD/OPTIONS | Exact method/URL/headers/body/status/time | Quick mocked method tests cover subset; device run absent | Partial | P1 |
| DD-MAN-051 | All | Query/headers with Unicode/reserved/repeated/empty values | Send and inspect wire bytes | Standards-correct encoding; duplicate limitation explicit | Map state collapses duplicate headers/query keys | Known limitation | P2 |
| DD-MAN-052 | Native | JSON/plain/empty/form/multipart text/file fixtures | Send each body | Exact content type/length/body and file bounds | JSON/plain work; form likely broken; no multipart files | Known failure: DD-API-004 | P1 |
| DD-MAN-053 | All | Environment hierarchy/unresolved variables/secret canaries | Resolve/send/switch/restart | Documented precedence; unresolved blocked; secrets protected | Resolver tests partial; secret storage unsafe | Blocked: DD-SEC-001 | P0 |
| DD-MAN-054 | Native | Delayed headers, stalled body, slow chunks | Send with short limits | Connect/read/total timeout terminates operation | Timeout wraps headers only | Known failure: DD-API-001 | P1 |
| DD-MAN-055 | All | Request in connect/header/body/assert/extract/delay phase | Cancel at each phase | No later network, persistence, assertion, report, or stale UI | Collection loop/state not terminally safe | Known failure: DD-API-002 | P1 |
| DD-MAN-056 | All | Two fake requests finish in reverse order; rapid Send calls | Invoke repeatedly | One policy-defined operation; newest result only; no duplicate side effect | Single active client pointer; UI disables common tap but provider race remains | Known risk: DD-API-002 | P1 |
| DD-MAN-057 | All | Empty, invalid JSON, binary, compressed, slow, oversized/infinite response | Send/view/save/cancel | Bounded preview, correct bytes/type, graceful save/truncate | Full unbounded text buffer | Known failure: DD-API-001 | P1 |
| DD-MAN-058 | Native/Web | Redirect, DNS fail, offline, TLS fail/self-signed, localhost IPv4/IPv6, proxy | Send | Redacted actionable outcome and documented platform behavior | No comprehensive tests; raw errors possible | Not run | P1 |
| DD-MAN-059 | Android/Windows/Web | HTTP endpoint | Send | Consistent warning/block and platform explanation | Android/web may block; Windows may send | Known UX gap: DD-API-005 | P2 |
| DD-MAN-060 | Web | Cooperative and non-cooperative CORS endpoints | Send with custom/auth headers | Clear browser limitation; no native-equivalence claim | Web build only | Not run | P1 |
| DD-MAN-061 | All | Canary in every request/response field | Save history/report, error, snippet, copy, export, backup | Canary only in explicitly approved protected sink | Redaction gaps confirmed | Blocked: DD-SEC-001/DD-API-003 | P0 |
| DD-MAN-062 | All | DevDesk current/legacy/future, Postman nested/forms, malformed/huge imports | Import preview/default strip/export/reimport | Version/limits enforced, safe defaults, semantic round trip | Shallow import/version gaps | Known risk | P1 |
| DD-MAN-063 | All | Collection with delay and a failing/canceled item | Run/cancel/restart | Deterministic stop/continue policy and accurate report | Cancel may allow later loop items | Known failure: DD-API-002 | P1 |

## Backup and storage recovery

| Test ID | Platform | Preconditions | Steps | Expected result | Actual result | Status | Severity when failed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DD-MAN-070 | All | Data in all 12 boxes, no real secrets | Export; inspect preview/document; import clean profile | All sections/metadata/counts correct; exact round trip | Export exists; preview omits vault registry entries | Partial: DD-BACKUP-002 | P1 |
| DD-MAN-071 | All | Empty/current/legacy/future/malformed/truncated/wrong-type/unknown fields | Preview/import each | Compatible only; zero mutation on rejection | Future version not rejected | Known failure: DD-BACKUP-002 | P1 |
| DD-MAN-072 | All | Huge/deep/duplicate/conflicting/invalid-date/enum backup | Preview/import | Enforced bounds and deterministic conflict report | Shallow validation/no deep bounds | Known risk | P1 |
| DD-MAN-073 | All | Fault injection after every clear/put; disk full; process kill | Replace import then restart | Exact rollback or journal recovery | Sequential nontransactional apply | Known failure: DD-BACKUP-001 | P0 |
| DD-MAN-074 | All | Existing conflicts | Merge twice | Documented idempotent outcome; no duplicates/loss | No domain conflict policy | Not run | P1 |
| DD-MAN-075 | All | Canary secrets in approved test fields | Export file and clipboard | Secrets excluded by default; explicit protected opt-in only | Whole boxes exported | Known failure: DD-SEC-001 | P0 |

## Platform, accessibility, and release artifacts

| Test ID | Platform | Preconditions | Steps | Expected result | Actual result | Status | Severity when failed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DD-MAN-080 | Android | Final signed APK/AAB; Android 24 and current | Clean install, upgrade, rollback, launch, picker/network/offline | All core flows pass; signer/update chain valid | Audit artifact debug-signed | Blocked: DD-REL-001 | P0 |
| DD-MAN-081 | Windows | Final signed installer/portable ZIP; clean standard-user VMs | Install/relocate/launch/update/rollback/uninstall | Complete runtime, valid signature, documented data retention | Only raw build output exists | Blocked: DD-REL-002 | P1 |
| DD-MAN-082 | Web | Final hosted candidate | Keyboard/zoom/storage/file/API/offline/PWA checks | Advertised core flows and documented limitations | Build passed only | Not run | P1 |
| DD-MAN-083 | Android/Windows | TalkBack/NVDA | Operate every primary flow, errors/results/diff/tree | Named controls, sensible order, live announcements, alternative output | No recorded assistive-tech pass | Not run: DD-A11Y-001 | P1 |
| DD-MAN-084 | All | 200% text/large OS font, dark/light/high contrast | Resize and operate each page | No clipped critical action; approved contrast/touch targets | No comprehensive evidence | Not run | P1 |
| DD-MAN-085 | Android/Windows/Web | Network interception and empty profile | Exercise every feature | Only disclosed user-triggered destinations; policy exactly matches | Policy contradictions confirmed | Blocked: DD-PRIV-001 | P1 |
| DD-MAN-086 | Android/Windows | Final artifacts | Verify manifest/permissions/backup/debuggable/signer; verify package signature/hash/inventory | Production-safe config and reproducible published hashes | Android debug signer; Windows unsigned/unpackaged | Blocked | P0 |

## Test evidence recording rule

For each release run, replace “Actual result” with the observed version/device/build identifier, concise evidence location, and pass/fail. A screenshot is not sufficient for data integrity, wire bytes, secret absence, signature, or rollback; attach logs/hashes/fixture comparisons with secrets redacted.
