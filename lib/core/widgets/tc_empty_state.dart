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
    );
  }
}
