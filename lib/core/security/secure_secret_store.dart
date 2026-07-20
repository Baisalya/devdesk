import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform-backed storage for API workspace secrets.
///
/// Android uses Android Keystore encryption. Windows uses DPAPI bound to the
/// current Windows user. Web intentionally reports unavailable because browser
/// storage cannot provide the same local-user protection boundary.
class SecureSecretStore {
  SecureSecretStore._();

  static const MethodChannel _channel = MethodChannel('devdesk/secure_secrets');
  static const String workspacePrefix = 'workspace:';

  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      // Unit tests and unsupported embedders may not have initialized a
      // ServicesBinding. Protected storage must fail closed, not break data
      // cleanup or startup recovery.
      return false;
    }
  }

  static Future<void> writeJson(String key, Map<String, dynamic> value) async {
    _validateKey(key);
    if (!await isAvailable()) {
      throw const SecureSecretStoreException(
        'Protected secret storage is unavailable on this platform.',
      );
    }
    try {
      await _channel.invokeMethod<void>('write', {
        'key': key,
        'value': jsonEncode(value),
      });
    } on PlatformException catch (error) {
      throw SecureSecretStoreException(
        'Could not protect the saved secret values.',
        code: error.code,
      );
    }
  }

  static Future<Map<String, dynamic>?> readJson(String key) async {
    _validateKey(key);
    if (!await isAvailable()) return null;
    try {
      final value = await _channel.invokeMethod<String>('read', {'key': key});
      if (value == null || value.isEmpty) return null;
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        throw const SecureSecretStoreException(
          'Protected secret data has an invalid format.',
        );
      }
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw const SecureSecretStoreException(
        'Protected secret data is corrupted.',
      );
    } on PlatformException catch (error) {
      throw SecureSecretStoreException(
        'Could not read protected secret values.',
        code: error.code,
      );
    }
  }

  static Future<void> delete(String key) async {
    _validateKey(key);
    if (!await isAvailable()) return;
    try {
      await _channel.invokeMethod<void>('delete', {'key': key});
    } on PlatformException catch (error) {
      throw SecureSecretStoreException(
        'Could not delete protected secret values.',
        code: error.code,
      );
    }
  }

  static Future<void> clearAll() async {
    if (!await isAvailable()) return;
    try {
      await _channel.invokeMethod<void>('clearAll');
    } on PlatformException catch (error) {
      throw SecureSecretStoreException(
        'Could not clear protected secret values.',
        code: error.code,
      );
    }
  }

  static String workspaceKey(String workspaceId) {
    return '$workspacePrefix$workspaceId';
  }

  static void _validateKey(String key) {
    if (key.isEmpty || key.length > 240 || key.contains('\u0000')) {
      throw const SecureSecretStoreException('Invalid protected-storage key.');
    }
  }
}

class SecureSecretStoreException implements Exception {
  final String message;
  final String? code;

  const SecureSecretStoreException(this.message, {this.code});

  @override
  String toString() => message;
}
