import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tc_icon_tile.dart';
import '../../classrooms/school_list_item.dart';

/// One school on the dashboard: its name, and how many classrooms and
/// programmes of this teacher's sit inside it.
class SchoolCard extends StatelessWidget {
  const SchoolCard({super.key, required this.school, this.onTap});

  final SchoolListItem school;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // TWO KEYS PER NOUN RATHER THAN A PLURAL RULE, matching how the classroom
    // card counts programmes. The app has no plural machinery, and "1
    // classrooms · 1 programmes" is the single most common row in this section:
    // most teachers have exactly one classroom at most of their schools.
    final classrooms =
        (school.classroomCount == 1
                ? 'dashboard.school_classroom_one'
                : 'dashboard.school_classroom_many')
            .tr(args: ['${school.classroomCount}']);
    final programmes =
        (school.programmeCount == 1
                ? 'dashboard.school_programme_one'
                : 'dashboard.school_programme_many')
            .tr(args: ['${school.programmeCount}']);

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
              const TcIconTile(icon: Icons.school_rounded),
              SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      school.name,
                      // TWO LINES, unlike the classroom row's one. School names
                      // are long by nature ("PSBB Learning Leadership Academy")
                      // and this row is the only place the full name is shown,
                      // so truncating it to one line would leave several schools
                      // indistinguishable from each other.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '$classrooms · $programmes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
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
