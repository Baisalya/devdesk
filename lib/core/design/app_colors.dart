import 'package:flutter/material.dart';

import '../../app/theme/devdesk_semantic_colors.dart';

class AppColors {
  static const Color seed = Color(0xFF2563EB);

  const AppColors._();

  static Color success(BuildContext context) =>
      DevDeskSemanticColors.of(context).success;

  static Color warning(BuildContext context) =>
      DevDeskSemanticColors.of(context).warning;

  static Color info(BuildContext context) =>
      DevDeskSemanticColors.of(context).info;

  static Color destructive(BuildContext context) =>
      Theme.of(context).colorScheme.error;

  static Color favorite(BuildContext context) =>
      DevDeskSemanticColors.of(context).favorite;

  static Color diffAdded(BuildContext context) =>
      DevDeskSemanticColors.of(context).diffAdded;

  static Color diffRemoved(BuildContext context) =>
      DevDeskSemanticColors.of(context).diffRemoved;

  static Color diffModified(BuildContext context) =>
      DevDeskSemanticColors.of(context).diffModified;

  static Color successContainer(BuildContext context) {
    return DevDeskSemanticColors.of(context).successContainer;
  }

  static Color warningContainer(BuildContext context) {
    return DevDeskSemanticColors.of(context).warningContainer;
  }

  static Color infoContainer(BuildContext context) {
    return DevDeskSemanticColors.of(context).infoContainer;
  }

  static Color codeBackground(BuildContext context) {
    return DevDeskSemanticColors.of(context).codeSurface;
  }
}
