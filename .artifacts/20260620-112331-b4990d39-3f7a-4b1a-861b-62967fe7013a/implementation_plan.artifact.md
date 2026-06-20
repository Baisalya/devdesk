# Implementation Plan - Diff Workspace / Code Compare Studio

Upgrade DevDesk Diff Checker into a professional Diff Workspace for text, JSON, code, files, folders, Git, and GitHub.

## User Review Required

- **New Dependency**: I propose adding `archive: ^3.6.1` to support ZIP extraction on Android for GitHub and folder comparison.
- **Git on Windows**: Requires `git` to be in the system PATH for local Git features.
- **GitHub Token**: Optional private repo support will allow users to provide a token, but it will not be persisted unless explicitly requested.

## Proposed Changes

### Core Models & Utils

Define the data structures for the Diff Workspace.

#### [NEW] [diff_models.dart](file:///C:/Users/baish/StudioProjects/devdesk/lib/features/diff_checker/models/diff_models.dart)
- `DiffSource`: Enum (Text, File, GitHub, Git, Snippet, API).
- `DiffContent`: Container for compared content (text, metadata).
- `DiffOptions`: Settings (ignore whitespace, case, etc.).
- `DiffResult`: Enhanced diff data with line numbers and summaries.
- `DiffSession`: For persisting history.

#### [NEW] [secret_utils.dart](file:///C:/Users/baish/StudioProjects/devdesk/lib/core/utils/secret_utils.dart)
- Logic to detect and mask secrets (tokens, keys, .env).

---

### Advanced Diff Engine

Upgrade the diff logic beyond simple text comparison.

#### [diff_utils.dart](file:///C:/Users/baish/StudioProjects/devdesk/lib/core/utils/diff_utils.dart)
- Support for side-by-side and inline formatting.
- Line-by-line diff generation.
- JSON-aware diffing (formatting, key order normalization).
- Patch generation (Unified Diff format).

#### [NEW] [patch_utils.dart](file:///C:/Users/baish/StudioProjects/devdesk/lib/core/utils/patch_utils.dart)
- Logic to apply/revert changes between left and right sides.

---

### File & Folder Comparison

#### [NEW] [folder_diff_service.dart](file:///C:/Users/baish/StudioProjects/devdesk/lib/features/diff_checker/provider/folder_diff_service.dart)
- Windows: Directory traversal and file-by-file comparison.
- Android: ZIP extraction and content comparison.
- Ignore patterns logic.

---

### Git & GitHub Integration

#### [NEW] [git_service.dart](file:///C:/Users/baish/StudioProjects/devdesk/lib/features/diff_checker/provider/git_service.dart)
- Windows: `Process.run` for read-only Git commands.
- Parse `git status` and `git diff` output.

#### [NEW] [github_service.dart](file:///C:/Users/baish/StudioProjects/devdesk/lib/features/diff_checker/provider/github_service.dart)
- HTTP client to fetch public repo ZIPs.
- GitHub URL parser (repo, branch, file).

---

### UI Refactoring

#### [diff_page.dart](file:///C:/Users/baish/StudioProjects/devdesk/lib/features/diff_checker/presentation/diff_page.dart)
- Transform into a `DiffWorkspace` with tabs: Text, Files, JSON, Git/GitHub.
- Implement responsive layout:
  - Windows: 3-pane (Tree + Left + Right).
  - Android: Tabbed/Stacked.
- Add conflict resolver UI elements.

#### [NEW] [diff_history_panel.dart](file:///C:/Users/baish/StudioProjects/devdesk/lib/features/diff_checker/presentation/widgets/diff_history_panel.dart)
- Sidebar or sheet to show previous comparison sessions.

---

### Integration with Existing Tools

#### [api_page.dart](file:///C:/Users/baish/StudioProjects/devdesk/lib/features/api_tester/presentation/api_page.dart)
- Add "Compare" action to responses.

#### [dashboard_page.dart](file:///C:/Users/baish/StudioProjects/devdesk/lib/features/dashboard/presentation/dashboard_page.dart)
- Update "Diff Checker" label and icon to "Diff Workspace".

---

## Verification Plan

### Automated Tests
- `flutter test test/features/diff_checker/diff_engine_test.dart`: Unit tests for text/JSON/code diffing.
- `flutter test test/core/utils/secret_utils_test.dart`: Secret detection and masking.
- `flutter test test/features/diff_checker/github_url_test.dart`: GitHub URL parsing.
- `flutter test test/features/diff_checker/git_parser_test.dart`: Git status/diff parsing.

### Manual Verification
- **Windows**:
  - Open a local Git repo and verify changed files list.
  - Compare two local folders with ignore patterns.
  - Test keyboard shortcuts (Ctrl+D, Ctrl+O).
- **Android**:
  - Import two ZIP files and compare.
  - Fetch a GitHub repo ZIP and compare with local text.
- **Cross-platform**:
  - Compare large JSON files and verify key-order-ignore works.
  - Export a diff report and check for secret masking.
