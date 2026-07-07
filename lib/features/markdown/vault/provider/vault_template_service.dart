class VaultTemplateService {
  static const Map<String, String> templates = {
    'README': '''
# Project Name

## Overview

## Features

- 

## Installation

```bash

```

## Usage

## License
''',
    'Changelog': '''
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

### Changed

### Fixed
''',
    'Privacy Policy': '''
# Privacy Policy

## Data Collection

This app is local-first and does not send data to a backend.

## Local Storage

## Contact
''',
    'Release Notes': '''
# Release Notes

## Version

## Highlights

## Fixes

## Known Issues
''',
    'API Docs': '''
# API Documentation

## Endpoint

`GET /path`

## Request

### Headers

### Parameters

## Response

```json
{}
```
''',
    'Bug Report': '''
# Bug Report

## Summary

## Steps to Reproduce

1. 

## Expected Result

## Actual Result

## Environment
''',
    'Meeting Notes': '''
# Meeting Notes

Date: 

## Attendees

## Agenda

## Notes

## Action Items

- [ ] 
''',
  };

  static String dailyNote(DateTime date) {
    final title = _isoDate(date);
    return '''
---
title: $title
tags: [daily]
status: draft
created: $title
---

# $title

## Notes

## Tasks

- [ ] 

## Links
''';
  }

  static String readmeFromFields({
    required String name,
    String description = '',
    Iterable<String> features = const [],
    String installation = '',
    String usage = '',
    String license = '',
  }) {
    final buffer = StringBuffer()
      ..writeln('# ${name.trim().isEmpty ? 'Project Name' : name.trim()}')
      ..writeln();
    if (description.trim().isNotEmpty) {
      buffer
        ..writeln(description.trim())
        ..writeln();
    }
    if (features.isNotEmpty) {
      buffer
        ..writeln('## Features')
        ..writeln();
      for (final feature in features) {
        if (feature.trim().isNotEmpty) {
          buffer.writeln('- ${feature.trim()}');
        }
      }
      buffer.writeln();
    }
    if (installation.trim().isNotEmpty) {
      buffer
        ..writeln('## Installation')
        ..writeln()
        ..writeln(installation.trim())
        ..writeln();
    }
    if (usage.trim().isNotEmpty) {
      buffer
        ..writeln('## Usage')
        ..writeln()
        ..writeln(usage.trim())
        ..writeln();
    }
    if (license.trim().isNotEmpty) {
      buffer
        ..writeln('## License')
        ..writeln()
        ..writeln(
            'This project is licensed under the ${license.trim()} license.')
        ..writeln();
    }
    return buffer.toString();
  }

  static String apiDocsFromRequest({
    required String name,
    required String method,
    required String url,
    Map<String, String> headers = const {},
    String body = '',
  }) {
    final buffer = StringBuffer()
      ..writeln('# $name')
      ..writeln()
      ..writeln('## Endpoint')
      ..writeln()
      ..writeln('`$method $url`')
      ..writeln();
    if (headers.isNotEmpty) {
      buffer
        ..writeln('## Headers')
        ..writeln();
      for (final entry in headers.entries) {
        buffer.writeln('- `${entry.key}`: `${entry.value}`');
      }
      buffer.writeln();
    }
    if (body.trim().isNotEmpty) {
      buffer
        ..writeln('## Request Body')
        ..writeln()
        ..writeln('```json')
        ..writeln(body.trim())
        ..writeln('```')
        ..writeln();
    }
    buffer
      ..writeln('## Response')
      ..writeln()
      ..writeln('```json')
      ..writeln('{}')
      ..writeln('```');
    return buffer.toString();
  }

  static String _isoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
