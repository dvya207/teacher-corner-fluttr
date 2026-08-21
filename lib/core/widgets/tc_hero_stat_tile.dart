import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Translucent white stat tile rendered on a navy hero (mockup pattern:
/// "32 Students" / "2 Programmes" inside the Classroom Detail hero, the
/// report heroes' Enrolled/Active tiles).
class TcHeroStatTile extends StatelessWidget {
  final String value;
  final String label;

  const TcHeroStatTile({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: AppColors.heroTileBg,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.statNumber
                .copyWith(color: AppColors.white, fontSize: 22.sp),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.tiny
                .copyWith(color: AppColors.white.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}
