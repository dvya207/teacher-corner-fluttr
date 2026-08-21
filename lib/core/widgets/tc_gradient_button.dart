import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// Sky→teal gradient pill CTA — the mockup's "Submit N Nominations" /
/// "Confirm N Students" bar. One of the two sanctioned gradient surfaces
/// (see DESIGN.md); every other CTA stays TcButton.
class TcGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const TcGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: AppDimensions.buttonHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: AppColors.ctaGradient,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
          child: InkWell(
            onTap: _enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      height: 20.r,
                      width: 20.r,
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18.r, color: AppColors.white),
                          SizedBox(width: 8.w),
                        ],
                        // Flexible + ellipsis so a long label never overflows
                        // the pill on narrow (small-phone) widths.
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.buttonText
                                .copyWith(color: AppColors.white),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
