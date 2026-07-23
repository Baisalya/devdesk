# OpenAPI Integration Guide

Open **OpenAPI Studio** from the dashboard or command palette. Paste an OpenAPI 3.x JSON or YAML document, then choose **Validate and inspect**.

The parser is limited to 10 MB and requires an OpenAPI 3.x version and `info.title`. It lists operations, required parameters, request content types, responses, component schemas, and JSON Pointer source locations.

**Create collection** generates a new API collection using the first server URL as `base_url`. Generated request descriptions retain the source JSON Pointer. The source specification remains canonical and is never modified.

The domain service can also generate linked Markdown and compare two parsed versions. Comparison reports removed operations or schemas, newly required parameters, removed properties, and property type changes as breaking; added operations are non-breaking. Complex JSON Schema compatibility, callbacks, links, security-scheme synthesis, and OpenAPI 2 conversion are outside this release.
