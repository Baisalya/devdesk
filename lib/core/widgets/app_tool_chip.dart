import 'package:flutter/material.dart';

class AppToolChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const AppToolChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}
