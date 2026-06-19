import 'package:flutter/widgets.dart';

class AppRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 12;

  const AppRadius._();

  static BorderRadius get small => BorderRadius.circular(sm);

  static BorderRadius get medium => BorderRadius.circular(md);

  static BorderRadius get large => BorderRadius.circular(lg);
}
