import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tc_icon_tile.dart';
import '../classroom_list_item.dart';

/// One classroom row on the classrooms screen: name, school, programme count.
///
/// THREE LINES, EACH ONE FIELD. This is the screen a teacher comes to in order
/// to FIND a classroom, and they arrive knowing either its name or its school.
/// Giving those two a line each means both are scannable straight down the left
/// edge, which a single concatenated subtitle never was.
///
/// WHAT THIS ROW DELIBERATELY NO LONGER SHOWS, since each was here once:
///
///   * The grade/section label. It duplicated the name for every classroom in
///     this data, where "7 A" IS the name and "Grade 7 · A" said it again.
///   * The student count. It is a property of the classroom rather than a way to
///     recognise it, and it belongs on the classroom's own screen where it
///     already appears.
///   * The programme chips, and the single counted chip that briefly replaced
///     them. A chip is an affordance and these were not tappable; as plain text
///     the count sits in the same reading column as the school above it.
///   * The STEM Club chip and its separate flask icon. Every row carries the
///     same tile, so a STEM club reads as one more classroom in the list rather
///     than as a different kind of object.
class ClassroomCard extends StatelessWidget {
  const ClassroomCard({super.key, required this.classroom, this.onTap});

  final ClassroomListItem classroom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final school = classroom.institutionName?.trim() ?? '';
    final programmeCount = classroom.distinctProgrammeCount;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spacing12),
          child: Row(
            children: [
              const TcIconTile(icon: Icons.home_rounded),
              SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      classroom.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle,
                    ),
                    if (school.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        school,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption,
                      ),
                    ],
                    // Omitted at zero rather than reading "0 Programmes". A
                    // classroom with no programme yet is a normal state early in
                    // a term, and the row should say nothing about programmes
                    // rather than say there are none.
                    if (programmeCount > 0) ...[
                      SizedBox(height: 2.h),
                      Text(
                        (programmeCount == 1
                                ? 'classrooms.programme_one'
                                : 'classrooms.programme_many')
                            .tr(args: ['$programmeCount']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
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
