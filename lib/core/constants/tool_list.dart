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
    name: 'Markdown Editor',
    route: '/markdown',
    icon: Icons.edit_document,
    description: 'Create, edit and preview markdown.',
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
    name: 'Diff Checker',
    route: '/diff',
    icon: Icons.compare_arrows,
    description: 'Compare two text blocks.',
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
