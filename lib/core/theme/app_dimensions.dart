import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Responsive dimension tokens (R2).
///
/// These are GETTERS, not `static const`, so every `.w`/`.h`/`.r` is evaluated
/// AFTER `ScreenUtilInit` has run (never at static initialization, which would
/// throw a LateInitializationError inside ScreenUtil). Spacing and component
/// heights scale with width/height; border radii use `.r` (the smaller of the
/// two scales) and are capped so small devices are not over-rounded.
class AppDimensions {
  AppDimensions._();

  // Spacing scale (from Ranjan's mockup) — width-scaled.
  static double get spacing4 => 4.w;
  static double get spacing8 => 8.w;
  static double get spacing12 => 12.w;
  static double get spacing16 => 16.w;
  static double get spacing20 => 20.w;
  static double get spacing24 => 24.w;
  static double get spacing32 => 32.w;

  // Border radius — `.r` (min scale) so corners stay proportionate; capped via
  // `clamp` so a small device is not visually over-rounded.
  static double get radiusInput => 8.r.clamp(6.0, 10.0);
  static double get radiusCard => 12.r.clamp(10.0, 16.0);
  static double get radiusSheet => 20.r.clamp(16.0, 24.0);
  static double get radiusButton => 25.r.clamp(20.0, 28.0);
  static double get radiusChip => 16.r.clamp(12.0, 20.0);

  // Component heights — height-scaled. App bar height stays a fixed 56 (a
  // platform chrome constant, like kToolbarHeight) so it is NOT scaled.
  static const double appBarHeight = 56.0;
  static double get bottomNavHeight => 70.h;
  static double get inputHeight => 56.h;
  static double get buttonHeight => 52.h;

  // Elevation — unitless render depth, NEVER scaled (per conversion rules).
  static const double elevationCard = 1.0;
  static const double elevationSheet = 4.0;
  static const double elevationBottomNav = 8.0;
}
