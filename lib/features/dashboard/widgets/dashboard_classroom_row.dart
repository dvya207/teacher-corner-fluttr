import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../classrooms/classroom_list_item.dart';

/// One classroom on the DASHBOARD: name, then school and programmes on a single
/// line beneath it.
///
/// NOT `ClassroomCard`, deliberately, though both describe a classroom. The
/// classrooms screen is a place to find one, so its row carries an icon tile and
/// gives the school and the programme count a line each. The dashboard is a
/// place to leave from, so its row is two lines and no icon: three of these sit
/// above a schools section and an awards section, and every pixel one of them
/// takes is a pixel the sections below it lose.
///
/// The two were briefly one widget with a `compact` flag. It grew a second
/// branch in every part of its build method, which is the point at which a flag
/// has stopped being a variant and become two widgets sharing a name.
class DashboardClassroomRow extends StatelessWidget {
  const DashboardClassroomRow({super.key, required this.classroom, this.onTap});

  final ClassroomListItem classroom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // School first, then the programmes it runs, joined only where they exist so
    // a classroom missing either never renders a dangling separator.
    //
    // ONE LINE, ELLIPSIZED. A classroom at a long-named school running two
    // programmes would otherwise wrap to three lines and make one row taller
    // than the two below it combined. The full list is one tap away and gives
    // each field its own line.
    final subtitle = [classroom.institutionName, ...classroom.programmeLabels]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
            vertical: AppDimensions.spacing12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      classroom.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: AppDimensions.spacing8),
              Icon(
                Icons.chevron_right_rounded,
                size: 22.r,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
