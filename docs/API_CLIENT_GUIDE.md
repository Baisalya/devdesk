# API Client Guide

API Workspaces store collections, folders, environments, variables, inherited authentication, requests, examples, assertions, extraction rules, run reports, and bounded history.

## Requests

Supported bodies include none, JSON, text, XML, HTML, YAML, GraphQL, URL-encoded form, and text-field multipart form data. JSON, XML, YAML, and GraphQL syntax is validated before a network request. Explicit content types are preserved. GET and HEAD multipart requests and credentials embedded in URLs are rejected.

Variables resolve by scope. Mark sensitive values as secret so the platform-protected overlay is used. Portable exports, backups, logs, and common clipboard flows omit or redact protected values.

## Reliability

Requests use separate connect, total, and read-idle timeouts, cancellation, and a bounded streamed response reader. Oversized or stalled responses stop safely. Binary responses receive a bounded preview rather than unbounded text decoding.

## Platform behavior

Android and Windows share the same request engine. Platform stores differ: Android uses Android Keystore-backed encryption and Windows uses DPAPI. Proxy customization, custom client certificates, certificate bypass, arbitrary binary multipart attachments, and automatic large-response streaming to a user file are not enabled in this release.
