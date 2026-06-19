import 'package:flutter/material.dart';

import '../design/app_spacing.dart';

class AppLoadingState extends StatelessWidget {
  final String label;

  const AppLoadingState({super.key, this.label = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(label),
          ],
        ),
      ),
    );
  }
}
