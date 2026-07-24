import 'package:flutter/material.dart';

/// Represents a developer tool available in DevDesk.
class DevTool {
  final String name;
  final String route;
  final IconData icon;
  final String description;

  const DevTool({
    required this.name,
    required this.route,
    required this.icon,
    required this.description,
  });
}

/// A static list of all tools supported in the app. This list drives the
/// dashboard UI and can be extended with new utilities.
const List<DevTool> tools = [
  DevTool(
    name: 'Developer Workspaces',
    route: '/workspaces',
    icon: Icons.workspaces_outline,
    description:
        'Manage local folders as knowledge bases with OKF dashboard support.',
  ),
  DevTool(
    name: 'Markdown Vault',
    route: '/vault',
    icon: Icons.folder_copy,
    description: 'A personal wiki for your notes with backlinks and file explorer.',
  ),
  DevTool(
    name: 'Markdown Editor',
    route: '/markdown',
    icon: Icons.edit_document,
    description: 'Simple, distraction-free editor for single Markdown files.',
  ),
  DevTool(
    name: 'README Generator',
    route: '/readme',
    icon: Icons.assignment,
    description: 'Interactive wizard to build professional GitHub README files.',
  ),
  DevTool(
    name: 'JSON Tools',
    route: '/json',
    icon: Icons.data_object,
    description: 'Validate, prettify, minify, and query JSON data structures.',
  ),
  DevTool(
    name: 'API Workspaces',
    route: '/api',
    icon: Icons.api,
    description: 'Postman-like workspace for testing and saving HTTP requests.',
  ),
  DevTool(
    name: 'OpenAPI Studio',
    route: '/openapi',
    icon: Icons.schema,
    description: 'Load Swagger/OpenAPI specs to test endpoints and generate collections.',
  ),
  DevTool(
    name: 'Unified Search',
    route: '/search',
    icon: Icons.manage_search,
    description: 'One search bar to find files across all your local workspaces.',
  ),
  DevTool(
    name: 'JWT Decoder',
    route: '/jwt',
    icon: Icons.lock_open,
    description: 'Safely decode and inspect JSON Web Tokens without sending them online.',
  ),
  DevTool(
    name: 'Regex Tester',
    route: '/regex',
    icon: Icons.code,
    description: 'Live testing tool for regular expressions with match highlighting.',
  ),
  DevTool(
    name: 'Base64 Tool',
    route: '/base64',
    icon: Icons.text_format,
    description: 'Instant conversion between text/binary and Base64 strings.',
  ),
  DevTool(
    name: 'URL Encoder/Decoder',
    route: '/url',
    icon: Icons.link,
    description: 'Fix broken links by encoding or decoding URL query parameters.',
  ),
  DevTool(
    name: 'Timestamp Converter',
    route: '/timestamp',
    icon: Icons.timer,
    description: 'Convert Unix timestamps to human-readable dates and back.',
  ),
  DevTool(
    name: 'UUID Generator',
    route: '/uuid',
    icon: Icons.confirmation_number,
    description: 'Quickly generate random Version 4 UUIDs for development.',
  ),
  DevTool(
    name: 'Diff Workspace',
    route: '/diff',
    icon: Icons.difference,
    description: 'Compare two text blocks or files side-by-side to see changes.',
  ),
  DevTool(
    name: 'Snippets/Notes',
    route: '/snippets',
    icon: Icons.note_alt,
    description: 'Save reusable code snippets and private developer notes.',
  ),
  DevTool(
    name: 'Settings',
    route: '/settings',
    icon: Icons.settings,
    description: 'Customize app appearance, theme, and data privacy.',
  ),
];
