import 'package:flutter/material.dart';

import '../design/app_breakpoints.dart';

class AppResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget compactBody;
  final Widget? mediumBody;
  final Widget expandedBody;
  final Widget? floatingActionButton;

  const AppResponsiveScaffold({
    super.key,
    this.appBar,
    required this.compactBody,
    this.mediumBody,
    required this.expandedBody,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final deviceClass = AppBreakpoints.of(context);
    final body = switch (deviceClass) {
      DeviceClass.compact => compactBody,
      DeviceClass.medium => mediumBody ?? expandedBody,
      DeviceClass.expanded => expandedBody,
    };
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}
