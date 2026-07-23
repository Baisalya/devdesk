# Markdown Knowledge Guide

## Open a knowledge workspace

Add a local folder from **Developer Workspaces**, then choose **Open knowledge**. Markdown files in nested folders are indexed within configured size and count limits. Hidden files, `.git`, build output, and dependency caches are excluded by default.

## Editing

The workspace supports edit, preview, and split modes; quick open; current-file find; outline navigation; multiple tabs; and `Ctrl+S`, `Ctrl+P`, and `Ctrl+F`. Drafts are saved separately from source files. If the source changes after a draft was created, DevDesk exposes the conflict instead of overwriting either version.

Use standard links (`[label](relative/file.md#heading)`) or wiki links (`[[Document Title#Heading]]`). The inspector shows backlinks, outgoing links, unresolved links, unlinked title mentions, related tags, and a bounded focused graph.

## Frontmatter

YAML frontmatter is parsed with a standards-capable YAML parser. Form edits patch only targeted top-level fields and preserve unknown fields, nested extension data, comments, and the raw body. Raw mode remains available for advanced structures.

## Safety and platform notes

Windows local-path workspaces can use verified expected-fingerprint saves. Android picker documents can be read and exported, but persistent document-tree editing is deliberately disabled until the app has a dedicated SAF adapter. Remote images are blocked to avoid tracking requests, and local workspace image rendering remains a documented limitation.
