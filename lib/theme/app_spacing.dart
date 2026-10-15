/// Single source of truth for spacing so screens stay visually consistent.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Content is capped at this width so it does not stretch edge to edge on a
  /// tablet.
  static const double maxContentWidth = 640;
}
