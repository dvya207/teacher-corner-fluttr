import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/models/classroom.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tc_icon_tile.dart';

/// One programme as a classroom carries it, tappable through to its detail.
///
/// Built from the DENORMALISED copy on `classrooms/{id}.programmes` and nothing
/// else, so a classroom listing five programmes costs no reads at all. The
/// catalogue document — description, code, grades, status — is fetched only when
/// a teacher taps through, which is the whole reason the denormalised name
/// exists in the data.
///
/// That is also why this card shows so little: the classroom's copy of a
/// programme holds an id and a display name. Adding a description here would
/// mean a read per row on every classroom screen.
class ProgrammeCard extends StatelessWidget {
  const ProgrammeCard({super.key, required this.programme, this.onTap});

  final ClassroomProgramme programme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
              const TcIconTile(icon: Icons.folder_outlined),
              SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // Never blank and never "null": falls back to the id,
                      // which at least identifies which programme this is.
                      programme.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'programme.view_details'.tr(),
                      style: AppTypography.caption,
                    ),
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
