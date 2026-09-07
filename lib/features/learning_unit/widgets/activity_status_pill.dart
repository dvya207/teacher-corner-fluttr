import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/models/workflow_progress.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// "Not Started" / "In Progress" / "Completed", as a dot and a word.
///
/// A DOT RATHER THAN A COLOURED PILL. The three states have to be told apart at
/// a glance on a card that also carries a subject chip, and three filled pills
/// in three colours turned the top of every card into a traffic light. The dot
/// carries the colour and the text carries the meaning, so the card stays
/// legible for a teacher who cannot separate the amber from the green.
class ActivityStatusPill extends StatelessWidget {
  const ActivityStatusPill({super.key, required this.status});

  final ActivityProgressStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, key) = switch (status) {
      ActivityProgressStatus.notStarted => (
        AppColors.textTertiary,
        'lu.status_not_started',
      ),
      ActivityProgressStatus.inProgress => (
        AppColors.warning,
        'lu.status_in_progress',
      ),
      ActivityProgressStatus.completed => (
        AppColors.successGreen,
        'lu.status_completed',
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.r,
            height: 7.r,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          // Flexible even inside a min-size Row. In landscape the design tokens
          // scale against a 360-wide baseline, so this label is ~2.2x its
          // portrait width while the card it sits in is not, and a pill that
          // cannot give way takes the whole row over the edge with it.
          Flexible(
            child: Text(
              key.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.tiny.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
