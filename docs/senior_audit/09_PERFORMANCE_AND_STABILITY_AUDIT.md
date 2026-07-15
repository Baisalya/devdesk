# Performance and Stability Audit

## Summary

No benchmark or runtime profiling suite exists. Normal-size automated tests and builds pass, but several operations accept untrusted/user-sized data and execute synchronously or buffer it completely. These are architectural risks confirmed from code; exact freeze/crash thresholds require profiling on low-end Android and typical Windows hardware.

| Area | Current behavior | Risk | Recommended control |
| --- | --- | --- | --- |
| Startup | Await Hive before UI; theme loads again asynchronously | Permanent blank/crash on storage failure; unmeasured cold start | Recovery shell, timings, lazy noncritical boxes |
| Dashboard | Small static registry; persisted preferences | Low for normal state; load errors hidden | Error state and startup benchmark |
| Markdown | Preview rebuilt on edits; external file up to 5 MiB | Main-isolate parse/layout jank and memory | Debounce, input budget, incremental/worker parse where measurable |
| Vault | Recalculate backlinks and rewrite notes after changes; 50 full versions/note | Superlinear growth, write amplification, large box | Index backlinks incrementally; bounded/delta versions; paging |
| JSON | Decode/re-encode plus recursive full tree | Deep recursion, huge tree widget/memory, UI freeze | Size/depth/node caps, worker parse, virtualized/lazy tree |
| Regex | `RegExp` matching synchronously | Catastrophic backtracking blocks app indefinitely | Pattern/input caps, worker with hard cancellation/timeout |
| Diff | Whole strings/files/ZIPs; diff-match-patch | CPU/memory blowup on large/repetitive input | Byte/line limits, worker, progress/cancel, algorithm budget |
| API | Full response buffering; timeout only to headers | Infinite/large stream hang/OOM | Bounded streaming, read/total timeouts, cancellation |
| History/reports | No retention cap | Startup/storage/render growth | User retention, caps, paging/pruning |
| Backup | Read/materialize all boxes; sequential import | Memory and partial-write risk | Limits, staged streaming, journal/rollback |
| ZIP | Whole decode before expanded checks | Zip-bomb OOM | Bounded streaming off UI isolate |
| Providers | Async constructors/futures; some missing disposal/operation IDs | Stale state, unhandled errors, write-after-clear | Lifecycle ownership, cancel tokens, AsyncValue/errors |

### DD-PERF-001: Unbounded main-isolate and network work can freeze or exhaust the app

- Severity: P1
- Category: Performance/Availability
- Status: Confirmed design risk; thresholds need runtime verification
- Platforms: All
- Evidence:
  - synchronous regex matching in regex page
  - recursive JSON tree in `json_page.dart`
  - `Markdown(data: ...)` on live edits at `markdown_page.dart:700`
  - whole diff/ZIP operations and `Response.fromStream`
- Current behaviour: Multiple tools accept pasted, picked, downloaded, or compressed user data without per-operation CPU/memory/depth/time budgets. Heavy transforms/rendering happen on the UI isolate or are fully buffered.
- Expected behaviour: Explicit budgets and user feedback; bounded memory; cancellation; worker isolation only for measured heavy operations; virtualized output.
- User impact: Frozen UI, OS “not responding,” lost edits, or process termination.
- Security or business impact: Local denial of service from untrusted files/endpoints and poor reliability on mobile hardware.
- Root cause: Correctness-first utility implementations assume small inputs while product file/network limits are inconsistent.
- Recommended fix: Define a shared resource-policy matrix; instrument first; add size/depth/node/line/entry/response caps; debounce Markdown; worker-isolate JSON/regex/diff/archive; virtualize trees/lists; stream responses/backups.
- Verification steps: Performance corpus with p50/p95 time, peak RSS, frame jank, cancellation latency, and recovery on low-end Android and baseline Windows; include regex bomb, deep JSON, repetitive diff, 5 MiB Markdown, ZIP bomb, stalled/large response.
- Estimated complexity: Large

### DD-PERF-002: Persistent collections grow without retention or scalable indexing

- Severity: P2
- Category: Performance/Storage
- Status: Confirmed
- Platforms: All
- Evidence:
  - API history/report storage has no global cap
  - `vault_provider.dart:223-258` retains 50 full note versions and rewrites recalculated backlinks
  - snippets are loaded as one list
- Current behaviour: Histories/reports/snippets/notes are eagerly read and often rendered as full collections. Vault modifications can trigger broad rewrites.
- Expected behaviour: Documented retention, pruning/export controls, pagination/lazy queries, bounded versions, and incremental indexes.
- User impact: Slower startup/navigation, larger backups, disk growth, and longer clear/import operations.
- Security or business impact: Larger sensitive-data footprint and eventual instability.
- Root cause: Feature-local persistence without aggregate data-volume design.
- Recommended fix: Add per-domain retention and metrics, lazy/paged views, indexed search where warranted, and incremental backlink updates; expose “clear history/reports” controls.
- Verification steps: 1/1k/10k/100k realistic records, long notes/versions, restart/search/delete/backup/import, disk usage, memory, and migration benchmarks.
- Estimated complexity: Medium/Large

## Crash and lifecycle risks

- Storage/bootstrap exceptions before UI and unhandled notifier loads.
- Strict record casts after schema drift or partial import.
- Provider methods completing after navigation/disposal and stale API response writes.
- Direct external writes interrupted by crash/disk-full.
- Regex/JSON/ZIP stack, CPU, and memory exhaustion.
- Raw errors shown after an async gap may use stale context in some large pages; systematic `mounted` review is required.
- GitHub/Diff controller/service lifecycle and HTTP operations are not bounded; page-created controller disposal needs targeted verification.

## Recommended performance test suite

1. Cold/warm startup with empty, normal, corrupt, and large boxes.
2. Frame timing and memory for 100 KiB/1 MiB/5 MiB Markdown with rapid edits.
3. JSON matrix by bytes, nodes, array width, and nesting depth; virtualized scroll.
4. Regex safe/invalid/zero-width/catastrophic cases with cancellation deadline.
5. Diff random/repetitive/line-ending/Unicode inputs by size.
6. API delayed header, stalled chunks, slow chunks, 10/100/500 MiB declared streams, binary, cancel/dispose.
7. ZIP entry-count/compression-ratio/path/CRC/truncation corpus with peak memory.
8. 10k history/reports/snippets and 5k interlinked vault notes; backup/restore timings.
9. Repeated navigation/theme changes and 100 request cancellations with leak snapshots.

Do not move small Base64/URL/timestamp/UUID operations to isolates. Apply workers only after thresholds and overhead are measured.
