import 'package:flutter/material.dart';

/// DevDesk intentionally never resolves Markdown images from the network.
/// This keeps previewing untrusted Markdown offline and prevents tracking
/// pixels, credential-bearing URLs, and unexpected remote requests.
Widget buildSafeMarkdownImage(Uri uri, String? title, String? alt) {
  final label = (alt == null || alt.trim().isEmpty) ? 'Markdown image' : alt;
  final remote = uri.scheme == 'http' || uri.scheme == 'https';
  return Semantics(
    image: true,
    excludeSemantics: true,
    label:
        remote ? '$label. Remote image blocked.' : '$label. Image not loaded.',
    child: Builder(
      builder: (context) {
        return Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_not_supported_outlined),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  remote
                      ? '$label — remote image blocked'
                      : '$label — image not loaded',
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
