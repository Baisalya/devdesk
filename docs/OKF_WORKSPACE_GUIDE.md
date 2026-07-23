# OKF Workspace Guide

DevDesk implements a permissive profile of the Open Knowledge Format v0.1 Draft. Markdown plus YAML frontmatter remains the source format.

## Validation

Open **OKF Health** from a registered knowledge workspace. The dashboard reports concept count, valid concepts, errors, warnings, unverified concepts, review-due concepts, and deprecated concepts. A concept document requires a `type`. Unknown fields and unknown concept types are accepted.

Broken links and missing indexes are diagnostics, not conformance errors. `index.md` and `log.md` are reserved but optional. DevDesk stable IDs, review dates, verification state, and deprecation fields are extensions and are labelled as such.

## Generation

The template gallery contains architecture, API, data, decision, guide, incident, project, runbook, service, standard, system, term, and troubleshooting concepts. Index and log generation is preview-first. Managed index sections use markers so custom prose outside the generated section is preserved.

Multi-file plans are applied one safe file at a time. If a later file changes concurrently, earlier successful files are not automatically rolled back; review the preview and keep version control enabled for larger generations.

## Versioning

The validator is isolated from the editor so future OKF revisions can be added without rewriting user content. Treat v0.1 as a draft and review compatibility when the upstream specification changes.
