import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tc_chip.dart';
import '../../../core/widgets/tc_icon_tile.dart';
import '../classroom_list_item.dart';

/// One classroom row: name, grade/section, institution, student count.
class ClassroomCard extends StatelessWidget {
  const ClassroomCard({super.key, required this.classroom, this.onTap});

  final ClassroomListItem classroom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Grade/section and institution on one line, joined only when both exist,
    // so a missing grade never leaves a dangling separator.
    final subtitle = [
      classroom.gradeSectionLabel,
      classroom.institutionName,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spacing12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TcIconTile(
                icon: classroom.isStemClub
                    ? Icons.science_outlined
                    : Icons.class_outlined,
              ),
              SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classroom.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption,
                      ),
                    ],
                    // Omitted entirely when unknown. "0 students" would be a
                    // claim about the classroom; a missing count is a claim
                    // about our read.
                    if (classroom.studentCounter != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'classrooms.students_count'.tr(
                          args: ['${classroom.studentCounter}'],
                        ),
                        style: AppTypography.tiny,
                      ),
                    ],
                    if (classroom.isStemClub ||
                        classroom.programmeLabels.isNotEmpty) ...[
                      SizedBox(height: AppDimensions.spacing8),
                      Wrap(
                        spacing: AppDimensions.spacing8,
                        runSpacing: AppDimensions.spacing4,
                        children: [
                          if (classroom.isStemClub)
                            TcChip(
                              label: 'classrooms.stem_club'.tr(),
                              color: AppColors.ispfTeal,
                            ),
                          for (final label in classroom.programmeLabels)
                            TcChip(label: label, color: AppColors.skyBlue),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
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
