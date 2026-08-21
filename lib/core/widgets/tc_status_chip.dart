import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum TcStatus { active, upcoming, ended }

/// Contest/event status chip per the mockup: Active (sky tint), Upcoming
/// (amber tint), Ended (grey tint). Generalizes the TcChip factories for
/// the status vocabulary the redesign uses everywhere.
class TcStatusChip extends StatelessWidget {
  final TcStatus status;

  /// Optional label override (defaults to the localized status name supplied
  /// by the caller via [label] — callers pass `'status.active'.tr()` etc. so
  /// this widget stays localization-agnostic).
  final String? label;

  const TcStatusChip({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    final (color, fallback) = switch (status) {
      TcStatus.active => (AppColors.skyBlue, 'Active'),
      TcStatus.upcoming => (AppColors.warning, 'Upcoming'),
      TcStatus.ended => (AppColors.textTertiary, 'Ended'),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.chipBackground(color),
        // 999 is a "fully rounded pill" sentinel, not a measured radius; leave
        // unscaled so the chip stays a pill on every device.
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label ?? fallback,
        style: AppTypography.tiny.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
