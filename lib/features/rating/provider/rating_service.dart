import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../presentation/rate_us_dialog.dart';

final ratingServiceProvider = Provider<RatingService>((ref) {
  return const RatingService();
});

/// Tracks when to ask for a rating and opens the appropriate destination.
///
/// Android builds open Google Play. Windows Store builds can supply their
/// product ID with `--dart-define=DEVDESK_WINDOWS_STORE_PRODUCT_ID=...`.
/// Portable Windows builds fall back to the DevDesk GitHub repository.
class RatingService {
  const RatingService();

  static const String _keyLastVersion = 'rate_us_last_version';
  static const String _keyLaunchCount = 'rate_us_launch_count';
  static const String _keyFirstLaunchDate = 'rate_us_first_launch_date';
  static const String _keyIsRated = 'rate_us_is_rated';
  static const String _keyDontShowAgain = 'rate_us_dont_show_again';

  static const int launchThreshold = 3;
  static const int daysThreshold = 3;

  static const String _androidPackageName = 'com.baishalya.devdesk';
  static const String _repositoryUrl = 'https://github.com/Baisalya/devdesk';
  static const String _windowsStoreProductId = String.fromEnvironment(
    'DEVDESK_WINDOWS_STORE_PRODUCT_ID',
  );

  static bool _isDialogVisible = false;

  bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows);

  String get primaryActionLabel {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Rate on Google Play';
    }
    if (defaultTargetPlatform == TargetPlatform.windows &&
        _windowsStoreProductId.isNotEmpty) {
      return 'Review in Microsoft Store';
    }
    return 'Star DevDesk on GitHub';
  }

  String get destinationDescription {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'This opens the DevDesk listing in Google Play.';
    }
    if (defaultTargetPlatform == TargetPlatform.windows &&
        _windowsStoreProductId.isNotEmpty) {
      return 'This opens the DevDesk listing in Microsoft Store.';
    }
    return 'The portable Windows release opens the DevDesk repository in '
        'your browser.';
  }

  /// Records one app launch and resets prompt choices for a new app version.
  Future<void> init() async {
    if (!isSupportedPlatform) return;

    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final lastVersion = prefs.getString(_keyLastVersion);
    final now = DateTime.now().toUtc();

    if (lastVersion != currentVersion) {
      await prefs.setString(_keyLastVersion, currentVersion);
      await prefs.setInt(_keyLaunchCount, 0);
      await prefs.setString(_keyFirstLaunchDate, now.toIso8601String());
      await prefs.setBool(_keyIsRated, false);
      await prefs.setBool(_keyDontShowAgain, false);
    } else if (DateTime.tryParse(
          prefs.getString(_keyFirstLaunchDate) ?? '',
        ) ==
        null) {
      await prefs.setString(_keyFirstLaunchDate, now.toIso8601String());
    }

    final launchCount = prefs.getInt(_keyLaunchCount) ?? 0;
    await prefs.setInt(_keyLaunchCount, launchCount + 1);
  }

  /// Returns true once either the launch or elapsed-day threshold is met.
  Future<bool> shouldShowDialog() async {
    if (!isSupportedPlatform) return false;

    final prefs = await SharedPreferences.getInstance();
    final isRated = prefs.getBool(_keyIsRated) ?? false;
    final dontShowAgain = prefs.getBool(_keyDontShowAgain) ?? false;
    if (isRated || dontShowAgain) return false;

    final launchCount = prefs.getInt(_keyLaunchCount) ?? 0;
    final firstLaunchDate = DateTime.tryParse(
      prefs.getString(_keyFirstLaunchDate) ?? '',
    );
    if (firstLaunchDate == null) return false;

    final daysSinceFirstLaunch =
        DateTime.now().toUtc().difference(firstLaunchDate.toUtc()).inDays;
    return launchCount >= launchThreshold ||
        daysSinceFirstLaunch >= daysThreshold;
  }

  Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsRated, true);
  }

  Future<void> markAsDontShow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDontShowAgain, true);
  }

  /// Starts a fresh three-launch/three-day waiting period.
  Future<void> remindLater() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLaunchCount, 0);
    await prefs.setString(
      _keyFirstLaunchDate,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Removes all rating-prompt state as part of the app's Clear All Data flow.
  Future<void> clearData() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyLastVersion),
      prefs.remove(_keyLaunchCount),
      prefs.remove(_keyFirstLaunchDate),
      prefs.remove(_keyIsRated),
      prefs.remove(_keyDontShowAgain),
    ]);
  }

  Future<void> showRateDialogIfMeetsCriteria(BuildContext context) async {
    try {
      if (await shouldShowDialog() && context.mounted) {
        await showRateDialog(context);
      }
    } catch (error, stackTrace) {
      debugPrint('Could not evaluate the rating prompt: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Shows the prompt immediately. Used by the manual Settings action too.
  Future<void> showRateDialog(BuildContext context) async {
    if (!isSupportedPlatform || !context.mounted || _isDialogVisible) return;

    _isDialogVisible = true;
    try {
      final action = await showDialog<RateUsAction>(
        context: context,
        barrierDismissible: false,
        builder: (context) => RateUsDialog(
          primaryActionLabel: primaryActionLabel,
          destinationDescription: destinationDescription,
        ),
      );

      switch (action) {
        case RateUsAction.rateNow:
          final launched = await _openRatingDestination();
          if (launched) {
            await markAsRated();
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open the rating page.'),
              ),
            );
          }
        case RateUsAction.remindLater:
          await remindLater();
        case RateUsAction.dontShowAgain:
          await markAsDontShow();
        case null:
          break;
      }
    } catch (error, stackTrace) {
      debugPrint('Could not complete the rating action: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The rating action could not finish.')),
        );
      }
    } finally {
      _isDialogVisible = false;
    }
  }

  Future<bool> _openRatingDestination() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      var packageName = _androidPackageName;
      try {
        packageName = (await PackageInfo.fromPlatform()).packageName;
      } catch (_) {
        // The known release package name remains a safe fallback.
      }
      return _launchFirst([
        Uri.parse('market://details?id=$packageName'),
        Uri.https(
          'play.google.com',
          '/store/apps/details',
          {'id': packageName},
        ),
      ]);
    }

    if (defaultTargetPlatform == TargetPlatform.windows &&
        _windowsStoreProductId.isNotEmpty) {
      return _launchFirst([
        Uri(
          scheme: 'ms-windows-store',
          host: 'review',
          path: '/',
          queryParameters: {'ProductId': _windowsStoreProductId},
        ),
        Uri.https('apps.microsoft.com', '/detail/$_windowsStoreProductId'),
      ]);
    }

    return _launchFirst([Uri.parse(_repositoryUrl)]);
  }

  Future<bool> _launchFirst(List<Uri> destinations) async {
    for (final destination in destinations) {
      try {
        if (await launchUrl(
          destination,
          mode: LaunchMode.externalApplication,
        )) {
          return true;
        }
      } catch (_) {
        // Continue to the browser fallback when a store protocol is absent.
      }
    }
    return false;
  }
}
