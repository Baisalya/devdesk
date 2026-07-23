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
        'Open local project folders without giving up ownership of your files.',
  ),
  DevTool(
    name: 'Markdown Vault',
    route: '/vault',
    icon: Icons.folder_copy,
    description: 'Local markdown vault with folders, backlinks and previews.',
  ),
  DevTool(
    name: 'Markdown Editor',
    route: '/markdown',
    icon: Icons.edit_document,
    description: 'Open, edit and save standalone markdown files.',
  ),
  DevTool(
    name: 'README Generator',
    route: '/readme',
    icon: Icons.assignment,
    description: 'Generate project READMEs quickly.',
  ),
  DevTool(
    name: 'JSON Tools',
    route: '/json',
    icon: Icons.data_object,
    description: 'Validate and format JSON.',
  ),
  DevTool(
    name: 'API Workspaces',
    route: '/api',
    icon: Icons.api,
    description: 'Manage offline API workspaces, collections and runners.',
  ),
  DevTool(
    name: 'OpenAPI Studio',
    route: '/openapi',
    icon: Icons.schema,
    description: 'Validate OpenAPI 3.x and generate API collections.',
  ),
  DevTool(
    name: 'Unified Search',
    route: '/search',
    icon: Icons.manage_search,
    description: 'Search local workspace and API metadata in one place.',
  ),
  DevTool(
    name: 'JWT Decoder',
    route: '/jwt',
    icon: Icons.lock_open,
    description: 'Inspect JWT payloads and expiry.',
  ),
  DevTool(
    name: 'Regex Tester',
    route: '/regex',
    icon: Icons.code,
    description: 'Test regular expressions.',
  ),
  DevTool(
    name: 'Base64 Tool',
    route: '/base64',
    icon: Icons.text_format,
    description: 'Encode and decode Base64.',
  ),
  DevTool(
    name: 'URL Encoder/Decoder',
    route: '/url',
    icon: Icons.link,
    description: 'Encode or decode URL text.',
  ),
  DevTool(
    name: 'Timestamp Converter',
    route: '/timestamp',
    icon: Icons.timer,
    description: 'Convert between timestamps and dates.',
  ),
  DevTool(
    name: 'UUID Generator',
    route: '/uuid',
    icon: Icons.confirmation_number,
    description: 'Generate v4 UUIDs.',
  ),
  DevTool(
    name: 'Diff Workspace',
    route: '/diff',
    icon: Icons.difference,
    description: 'Compare text, JSON, files, folders, Git, and GitHub.',
  ),
  DevTool(
    name: 'Snippets/Notes',
    route: '/snippets',
    icon: Icons.note_alt,
    description: 'Store notes and code snippets.',
  ),
  DevTool(
    name: 'Settings',
    route: '/settings',
    icon: Icons.settings,
    description: 'Configure themes and preferences.',
  ),
];
