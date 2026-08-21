import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class TcEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const TcEmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      // Scrollable rather than a bare Padding: the tokens scale `.w` against a
      // 360-wide baseline, so in landscape (800x360) the padding and the 64dp
      // icon grow while the available height collapses, and a fixed Column
      // overflowed by 144px. Sizes to its content when it fits, so it stays
      // centred on a portrait phone.
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64.r, color: AppColors.textDisabled),
              SizedBox(height: 16.h),
              Text(title, style: AppTypography.heading3.copyWith(color: AppColors.textSecondary)),
              if (subtitle != null) ...[
                SizedBox(height: 8.h),
                Text(subtitle!, style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary), textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
