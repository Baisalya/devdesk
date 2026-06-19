# DevDesk

DevDesk is a **pure Flutter** developer toolbox designed to work completely offline. It bundles a suite of everyday utilities—such as a Markdown editor, JSON viewer/formatter, mini‑Postman API tester, JWT decoder, regex tester, Base64 encoder/decoder, timestamp converter, UUID generator, diff checker, and snippets/notes storage—into one cohesive, beginner‑friendly application. There is **no backend** or cloud dependency; all data is stored locally on device.

## Features

The app includes the following tools:

| Tool | Description |
| --- | --- |
| Dashboard | Lists all available tools, shows favorites and recently used items, and provides a search bar for quick access. |
| Markdown Editor | Create and edit markdown files with a live preview. Supports headings, bold, italics, code blocks, links, lists, checklists and tables. Files are saved locally and can be exported. |
| README Generator | Build a clean README.md by filling out a form with your project’s name, description, features, install instructions, usage, screenshots note and license. Allows editing after generation. |
| JSON Viewer & Formatter | Paste JSON to validate, pretty‑print, minify and explore via a tree view. Displays helpful error messages with line information on invalid input. |
| API Tester | A mini‑Postman built into Flutter. Supports GET, POST, PUT, PATCH and DELETE. Allows editing headers, query parameters and request body. Shows status code, response time, headers and body with pretty‑printed JSON. Supports saving history, duplicating requests, presets, environments, and code snippet generation. |
| JWT Decoder | Decodes the header and payload of a JWT locally, highlighting expiry time and whether the token is expired. Does not verify the signature or send the token anywhere. |
| Regex Tester | Tests a regular expression against sample text, shows matches and counts, and reports errors. Supports common flags. |
| Base64 Tool | Encodes and decodes Base64 strings and provides clear error messages for invalid input. |
| URL Encoder/Decoder | Encodes text for safe use in URLs or decodes encoded URL text back to human‑readable form. |
| Timestamp Converter | Converts Unix timestamps (seconds or milliseconds) to local and UTC date/times, and vice versa. |
| UUID Generator | Generates version‑4 UUIDs one at a time or in batches. |
| Diff Checker | Compares two blocks of text and highlights differences. Useful for JSON or arbitrary text comparison. |
| Snippets/Notes | Stores developer notes and command snippets with tags. Supports search, editing, deletion and local export/import. |
| Settings | Toggles light/dark/system theme, clears local data with confirmation, exports/imports data backups, and displays an About page. |

## Project structure

DevDesk follows a feature‑based structure with clean separation between presentation, provider (state), data storage and utilities. The top‑level `lib/` directory is organised as follows:

```
lib/
  main.dart            # Entry point and MaterialApp setup
  app/
    app.dart           # Root widget
    router.dart        # Simple router for feature pages
    theme/
      light_theme.dart
      dark_theme.dart
  core/
    constants/         # Hard‑coded lists (e.g. tool metadata)
    errors/            # Failure classes
    storage/           # Local storage helpers (Hive wrappers)
    utils/             # Utility functions (JSON, regex, Base64, URL, timestamp, UUID, diff, JWT)
    widgets/           # Reusable UI components
  features/
    dashboard/
      presentation/     # Dashboard UI and widgets
      provider/         # Dashboard state management
    markdown/
      presentation/
      provider/
    readme_generator/
      presentation/
      provider/
    json_tools/
      presentation/
      provider/
    api_tester/
      presentation/
      provider/
      models/
    jwt_decoder/
      presentation/
      provider/
    regex_tester/
      presentation/
      provider/
    base64_tool/
      presentation/
      provider/
    url_tool/
      presentation/
      provider/
    timestamp_tool/
      presentation/
      provider/
    uuid_tool/
      presentation/
      provider/
    diff_checker/
      presentation/
      provider/
    snippets/
      presentation/
      provider/
    settings/
      presentation/
      provider/
```

## Running the app

To run DevDesk locally:

1. Install [Flutter](https://flutter.dev/docs/get-started/install) and ensure your environment is set up with `flutter doctor`.
2. Clone this repository and navigate into the project directory:

   ```bash
   git clone <repo-url>
   cd devdesk
   ```

3. Fetch dependencies and generate Hive adapters:

   ```bash
   flutter pub get
   ```

4. Run the app on an emulator or device:

   ```bash
   flutter run
   ```

5. Execute tests to verify functionality:

   ```bash
   flutter test
   ```

## Contributing

Contributions, bug reports and feature requests are welcome! Feel free to open an issue or submit a pull request. When contributing code, please ensure that you follow the project structure, keep business logic outside of UI widgets, add tests for your changes, and run `flutter analyze` and `dart format` before submitting.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for more information.
## External files

DevDesk can open user-selected developer files without broad storage permission. Supported files include Markdown/README files, JSON, text and common code files, DevDesk backup JSON, and DevDesk API collection JSON.

- Android uses the system file picker flow and treats selected files as safe read copies. Use Save As/export copy for edited external content.
- Windows uses normal open/save dialogs and can overwrite the original file after confirmation when the selected path is writable.
- `.env` files show a secrets warning before opening. File contents, tokens, request bodies, and authorization headers are not logged or uploaded.
- Backup imports show a preview before data is merged or replaced.
- API collection imports warn when sensitive headers are present and default to importing without secrets.
