import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class TcChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const TcChip({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
  });

  factory TcChip.completed() => TcChip(label: 'Completed', color: AppColors.successGreen);
  factory TcChip.pending() => TcChip(label: 'Pending', color: AppColors.amber);
  factory TcChip.synced() => TcChip(label: 'Synced', color: AppColors.skyBlue);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: filled ? color : AppColors.chipBackground(color),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: filled ? AppColors.white : color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
