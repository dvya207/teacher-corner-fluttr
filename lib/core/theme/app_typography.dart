import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

/// Responsive, Material-comfortable text styles (R2 + readability tuning).
///
/// Brand fonts are unchanged: Montserrat for headings/labels/buttons, Noto Sans
/// for body/content/inputs. The .ttf files are bundled under assets/fonts and
/// declared in pubspec.yaml, so these family names resolve to the brand fonts
/// (no GoogleFonts runtime fetch). This is the SINGLE source of truth for text
/// sizing; screens should use these tokens (via `.copyWith` for one-off colour)
/// rather than inline `fontSize:` literals.
///
/// Sizing rules:
///  * Every style is a GETTER so `.sp` is evaluated AFTER `ScreenUtilInit`.
///  * `fontSize` uses `.sp` (width-resolved) as the single size-scaling source.
///  * FLOOR: no meaningful text is below 12sp (was 9-11sp before tuning).
///  * `height` (unitless line-height) and `letterSpacing` (tracking) are NOT
///    scaled, per the conversion rules; they are tuned for readability.
class AppTypography {
  AppTypography._();

  // Line-height multipliers (unitless; not scaled).
  static const double _hHeading = 1.25;
  static const double _hBody = 1.45;

  // ---- Montserrat: headings, section labels, buttons ----

  /// Page / display title.
  static TextStyle get heading1 => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 30.sp, fontWeight: FontWeight.w700, height: _hHeading,
    color: AppColors.navy,
  );

  static TextStyle get heading2 => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 24.sp, fontWeight: FontWeight.w700, height: _hHeading,
    color: AppColors.navy,
  );

  static TextStyle get heading3 => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 22.sp, fontWeight: FontWeight.w600, height: _hHeading,
    color: AppColors.navy,
  );

  static TextStyle get appBarTitle => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 20.sp, fontWeight: FontWeight.w600, color: AppColors.white,
  );

  static TextStyle get cardTitle => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 17.sp, fontWeight: FontWeight.w600, height: _hHeading,
    color: AppColors.charcoal,
  );

  /// Section header: clearly above body, bold for hierarchy.
  static TextStyle get sectionTitle => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.navy,
  );

  static TextStyle get label => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
  );

  static TextStyle get stepLabel => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.skyBlue,
    letterSpacing: 1.0,
  );

  static TextStyle get buttonText => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.white,
  );

  // ---- Noto Sans: body, content, inputs ----

  static TextStyle get bodyLarge => TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 16.sp, fontWeight: FontWeight.w400, height: _hBody,
    color: AppColors.charcoal,
  );

  /// Primary body text.
  static TextStyle get bodyMedium => TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 15.sp, fontWeight: FontWeight.w400, height: _hBody,
    color: AppColors.charcoal,
  );

  /// Emphasised body (use for highlighted values inline with body text).
  static TextStyle get bodyStrong => TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 15.sp, fontWeight: FontWeight.w600, height: _hBody,
    color: AppColors.charcoal,
  );

  static TextStyle get bodySmall => TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 14.sp, fontWeight: FontWeight.w400, height: _hBody,
    color: AppColors.charcoal,
  );

  /// Secondary / supporting text. Floor for readable supporting copy.
  static TextStyle get caption => TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 13.sp, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );

  /// Smallest permitted size for meaningful microcopy (badges, timestamps).
  static TextStyle get tiny => TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 12.sp, fontWeight: FontWeight.w400, color: AppColors.textTertiary,
  );

  static TextStyle get inputText => TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 16.sp, fontWeight: FontWeight.w400, color: AppColors.charcoal,
  );

  /// Large emphasised number (dashboard stats / counts).
  static TextStyle get statNumber => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 32.sp, fontWeight: FontWeight.w700,
  );
}
