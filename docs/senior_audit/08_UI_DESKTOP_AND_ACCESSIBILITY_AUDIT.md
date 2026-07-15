# UI, Desktop, and Accessibility Audit

## Overall assessment

The UI has consistent Material styling, shared cards/panels/empty states, dark/light/system themes, and several responsive layouts. It is usable for ordinary pointer/touch flows. It is not yet a verified accessible or desktop-native application.

## Android UX

- Dashboard grid responds to width and common pages use scrolling/layout builders. Touch workflows are generally direct.
- System picker avoids broad storage permission. Android content URIs often cannot support “overwrite original,” so Save As is the practical path.
- Back navigation in Markdown/text pages prompts for unsaved changes. App/process termination and some lifecycle cases are not protected.
- Phone/tablet tests are mostly synthetic sizes, not device integration. Text scaling, IME overlap, rotation, split-screen, TalkBack, Android back gesture, and picker provider differences are unverified.
- API tester needs platform-specific cleartext/localhost/self-signed/CORS-equivalent explanation; loading and cancellation must remain visible during lifecycle changes.

## Windows UX

- The native runner enforces a 900×600 minimum (`windows/runner/win32_window.cpp:210-216`), reducing severe narrow overflow but excluding smaller windows.
- Wide editor layouts and pointer controls are reasonable. The product lacks a consistent menu/command surface, window-close unsaved protection, recent-file integration, drag/drop, context menus, native file error recovery, and multi-instance behavior.
- Branding remains lowercase `devdesk` in executable metadata/title (`Runner.rc:92-98`, `main.cpp:30`).
- The prominent Diff file/Git/GitHub/export controls create broken affordances rather than graceful unavailable states.

## Web limitations

- Compilation succeeds, but native file semantics become picker/download semantics and overwrite-original cannot be equivalent.
- Arbitrary API requests are constrained by CORS, preflight, mixed content, forbidden headers, cookies/credentials, and exposed response headers.
- Browser storage/clipboard/download persistence differs from native and should be documented. The current web title/manifest remain generic lowercase `devdesk`.
- Web was not manually tested for keyboard focus, screen readers, browser zoom, PWA install/offline behavior, or API limitations.

## Responsive layout and states

Strengths:

- Reusable breakpoints/design tokens and dashboard grid.
- Empty search/recent/snippet states and many loading/snackbar paths.
- Destructive confirmations for clear data and external overwrite.

Gaps:

- Several pages are very large and use fixed/max constraints; extreme text scale and localization are untested.
- Async provider constructors often do not expose error/retry states. Raw exception snackbars replace actionable recovery.
- API, backup, and file operations need progress phases, terminal cancellation, retry, and clear partial-failure messaging.
- Unsaved-change prompts cover in-app navigation, not Windows close, Android kill, crash, or restart recovery.

### DD-UI-001: Desktop workflows lack a coherent keyboard command model

- Severity: P2
- Category: UI/Desktop
- Status: Confirmed
- Platforms: Windows/Web
- Evidence:
  - Dashboard and feature pages rely primarily on standard widget traversal and pointer actions
  - No app-level shortcut/command registry
- Current behaviour: Text controls inherit basic editing keys, while tool search/open/save/send/new/cancel/navigation actions have no consistent shortcuts or discoverability.
- Expected behaviour: A centralized command model with focus-safe shortcuts, menu/tooltips, conflict handling, and accessible discoverability.
- User impact: Repetitive mouse use and slower developer workflow.
- Security or business impact: Lower desktop product quality; accidental duplicate/destructive actions if shortcuts are added ad hoc.
- Root cause: Mobile-first page actions without application-level intent/actions architecture.
- Recommended fix: Add command registry and `Shortcuts`/`Actions`; start with Ctrl+K tool search, Ctrl+O open, Ctrl+S save, Ctrl+Shift+S Save As, Ctrl+Enter send, Ctrl+L API URL, Ctrl+N context new, Esc close/cancel. Respect focused text fields and platform conventions.
- Verification steps: Full keyboard walkthrough, shortcut conflicts, repeat keys, IME, alternate layouts, screen-reader announcements, disabled/busy states, and web browser conflicts.
- Estimated complexity: Medium

### DD-A11Y-001: Accessibility semantics and assistive-technology behavior are unverified

- Severity: P2
- Category: Accessibility
- Status: Needs Runtime Verification
- Platforms: All
- Evidence:
  - No semantics-focused test suite or documented TalkBack/NVDA/VoiceOver pass
  - Dense custom editor/diff/tree surfaces
- Current behaviour: Many controls have visible labels/tooltips, but focus order, semantic names/states, dynamic announcements, error association, contrast/high contrast, touch targets, text scaling, and accessible diff/tree output are not comprehensively tested.
- Expected behaviour: WCAG-informed keyboard/focus/contrast semantics, announced loading/errors/results, 200% text scaling, accessible alternatives for visual diffs/trees, and platform screen-reader verification.
- User impact: Keyboard and assistive-technology users may be unable to discover or operate core tools.
- Security or business impact: Exclusion, store/organizational acceptance risk, and support burden.
- Root cause: Accessibility is incidental rather than an acceptance criterion.
- Recommended fix: Establish semantics/focus checklist and tests, add live-region announcements and accessible textual diff/tree modes, verify contrast/touch targets/scaling, and run TalkBack plus NVDA before release.
- Verification steps: Screen readers, keyboard-only, switch-like traversal, 200%/large OS fonts, high contrast, dark/light contrast, reduced motion, and every error/loading/confirmation flow.
- Estimated complexity: Large

## Recommended state and error improvements

- Provide startup recovery for storage failure and retryable feature-load states.
- Replace raw exception strings with actionable, redacted errors and optional local diagnostic details.
- Show backup import as Validate → Preview → Applying → Verified/Rolled back.
- Show API phases (connecting, receiving, truncated/saving, canceled) with stable request identity.
- Disable or remove UI-only Diff actions until implemented; never celebrate a no-op export.
- Confirm window/app close for dirty documents or restore drafts on next launch.

## Accessibility release gate

Before public release, every primary tool must be operable by keyboard, have named controls and deterministic focus, survive large text without clipped critical actions, announce errors/results, and receive at least one Android TalkBack and Windows NVDA manual pass. VS Code's command/shortcut discoverability and accessible unified diff are useful reference patterns, not a requirement to copy its complexity.
