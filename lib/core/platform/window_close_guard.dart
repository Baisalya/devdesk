import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/command_registry.dart';

/// Coordinates dirty-document state with the Windows runner. The native
/// window delays WM_CLOSE while any registered editor is dirty; Flutter then
/// presents one accessible confirmation dialog before allowing termination.
class WindowCloseGuard {
  WindowCloseGuard._();

  static const MethodChannel _channel = MethodChannel(
    'devdesk/window_lifecycle',
  );
  static final Map<String, bool> _dirtyOwners = <String, bool>{};
  static bool _initialized = false;
  static bool _dialogOpen = false;

  static Future<void> initialize() async {
    if (_initialized ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'closeRequested') await _confirmWindowClose();
    });
    await _publish();
  }

  static Future<void> setDirty(String owner, bool dirty) async {
    if (dirty) {
      _dirtyOwners[owner] = true;
    } else {
      _dirtyOwners.remove(owner);
    }
    await _publish();
  }

  static Future<void> clear(String owner) => setDirty(owner, false);

  static Future<void> _publish() async {
    if (!_initialized ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setDirty', {
        'dirty': _dirtyOwners.isNotEmpty,
      });
    } on MissingPluginException {
      // Non-Windows tests and unsupported runners intentionally no-op.
    } on PlatformException {
      // In-app route guards still protect navigation if the bridge fails.
    }
  }

  static Future<void> _confirmWindowClose() async {
    if (_dialogOpen) return;
    final context = devDeskNavigatorKey.currentContext;
    if (context == null) return;
    _dialogOpen = true;
    final close = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Close DevDesk?'),
        content: const Text(
          'One or more documents have unsaved changes. Close and discard them?',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard and close'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (close != true) return;
    _dirtyOwners.clear();
    try {
      await _channel.invokeMethod<void>('confirmClose');
    } on PlatformException {
      // The user can retry the native close action.
    }
  }
}
