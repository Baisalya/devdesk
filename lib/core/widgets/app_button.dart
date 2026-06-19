import 'package:flutter/material.dart';

class AppPrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData? icon;
  final String label;

  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return FilledButton(onPressed: onPressed, child: Text(label));
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData? icon;
  final String label;

  const AppSecondaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return OutlinedButton(onPressed: onPressed, child: Text(label));
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
