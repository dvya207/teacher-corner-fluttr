import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// `navy` is the sign-in mockup's CTA. It is additive: every existing call site
/// keeps `primary` (sky) untouched.
enum TcButtonVariant { primary, navy, outlined, success, danger }

class TcButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final TcButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  const TcButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = TcButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _variantColors;
    final child = isLoading
        ? SizedBox(height: 20.r, width: 20.r, child: CircularProgressIndicator(
            strokeWidth: 2, color: colors.$2))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18.r, color: colors.$2),
                SizedBox(width: 8.w),
              ],
              // Flexible + ellipsis so a long label never overflows the button
              // on narrow (small-phone) widths.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.buttonText.copyWith(color: colors.$2),
                ),
              ),
            ],
          );

    if (variant == TcButtonVariant.outlined || variant == TcButtonVariant.danger) {
      return SizedBox(
        height: AppDimensions.buttonHeight,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colors.$1, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: AppDimensions.buttonHeight,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: colors.$1),
        child: child,
      ),
    );
  }

  (Color, Color) get _variantColors => switch (variant) {
    TcButtonVariant.primary => (AppColors.skyBlue, AppColors.white),
    TcButtonVariant.navy => (AppColors.navy, AppColors.white),
    TcButtonVariant.outlined => (AppColors.skyBlue, AppColors.skyBlue),
    TcButtonVariant.success => (AppColors.successGreen, AppColors.white),
    TcButtonVariant.danger => (AppColors.errorRed, AppColors.errorRed),
  };
}
