import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:devdesk/features/rating/presentation/rate_us_dialog.dart';
import 'package:devdesk/features/rating/provider/rating_service.dart';

void main() {
  const service = RatingService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'DevDesk',
      packageName: 'com.baishalya.devdesk',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('init resets a new version and records each launch', () async {
    SharedPreferences.setMockInitialValues({
      'rate_us_last_version': '0.9.0',
      'rate_us_launch_count': 20,
      'rate_us_first_launch_date':
          DateTime.now().subtract(const Duration(days: 20)).toIso8601String(),
      'rate_us_is_rated': true,
      'rate_us_dont_show_again': true,
    });

    await service.init();
    var prefs = await SharedPreferences.getInstance();

    expect(prefs.getString('rate_us_last_version'), '1.0.0');
    expect(prefs.getInt('rate_us_launch_count'), 1);
    expect(prefs.getBool('rate_us_is_rated'), isFalse);
    expect(prefs.getBool('rate_us_dont_show_again'), isFalse);

    await service.init();
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('rate_us_launch_count'), 2);
  });

  test('prompt becomes eligible after three launches', () async {
    SharedPreferences.setMockInitialValues({
      'rate_us_last_version': '1.0.0',
      'rate_us_launch_count': RatingService.launchThreshold,
      'rate_us_first_launch_date': DateTime.now().toIso8601String(),
      'rate_us_is_rated': false,
      'rate_us_dont_show_again': false,
    });

    expect(await service.shouldShowDialog(), isTrue);

    await service.markAsRated();
    expect(await service.shouldShowDialog(), isFalse);
  });

  test('prompt becomes eligible after three days', () async {
    SharedPreferences.setMockInitialValues({
      'rate_us_last_version': '1.0.0',
      'rate_us_launch_count': 1,
      'rate_us_first_launch_date': DateTime.now()
          .subtract(const Duration(days: RatingService.daysThreshold))
          .toIso8601String(),
      'rate_us_is_rated': false,
      'rate_us_dont_show_again': false,
    });

    expect(await service.shouldShowDialog(), isTrue);
  });

  test('remind later starts a fresh waiting period', () async {
    SharedPreferences.setMockInitialValues({
      'rate_us_launch_count': 30,
      'rate_us_first_launch_date':
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      'rate_us_is_rated': false,
      'rate_us_dont_show_again': false,
    });

    await service.remindLater();

    expect(await service.shouldShowDialog(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('rate_us_launch_count'), 0);
  });

  test('unsupported platforms never show an automatic prompt', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({
      'rate_us_launch_count': 100,
      'rate_us_first_launch_date':
          DateTime.now().subtract(const Duration(days: 100)).toIso8601String(),
    });

    expect(service.isSupportedPlatform, isFalse);
    expect(await service.shouldShowDialog(), isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('dialog returns the selected reminder action', (tester) async {
    RateUsAction? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<RateUsAction>(
                  context: context,
                  builder: (_) => const RateUsDialog(
                    primaryActionLabel: 'Rate on Google Play',
                    destinationDescription: 'Opens Google Play.',
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Enjoying DevDesk?'), findsOneWidget);

    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();
    expect(result, RateUsAction.remindLater);
  });
}
