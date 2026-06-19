# Changelog

All notable changes to **DevDesk** will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] – 2026‑06‑19

### Added

- Initial release of DevDesk, a pure Flutter developer toolbox app.
- Dashboard with search, favourites and recent tools.
- Fully functional Markdown editor with live preview and toolbar.
- README generator form with export/edit capabilities.
- JSON viewer and formatter with pretty‑print, minify and tree view modes.
- Mini Postman API tester supporting GET, POST, PUT, PATCH, DELETE with history, presets and environment variables.
- JWT decoder tool to inspect header/payload and expiry information.
- Regex tester with match highlighting and error reporting.
- Base64 encoder/decoder, URL encoder/decoder and timestamp converter.
- UUID generator and diff checker utilities.
- Local snippets and notes with tagging, search, edit and deletion.
- Settings page with theme selection, data export/import, clear data and About.
- Hive‑based local storage for requests, notes and user preferences.
- Complete test suite covering unit logic and key widgets.
- Release, privacy and changelog documentation.
## [1.0.1] - Unreleased

### Added

- Safe external file open/view/edit/export flows for Markdown/README, JSON, text/code, API collection JSON, and DevDesk backup JSON.
- Dashboard Open File quick action with local file type detection and `.env` warning.
- Text/code file editor with search, copy, Save As, and Save as Snippet.
- Versioned backup export/import with preview counts and replace/merge options.
- API collection import/export with sensitive header stripping by default.
- Windows minimum window size for desktop layout stability.

### Changed

- Markdown and JSON tools can open external documents while keeping internal Hive storage flows intact.
- README generator can export generated README.md through the platform save flow.
