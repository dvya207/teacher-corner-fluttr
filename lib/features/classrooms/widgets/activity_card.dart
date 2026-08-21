import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tc_chip.dart';
import '../../../core/widgets/tc_icon_tile.dart';
import '../../../core/widgets/tc_status_message.dart';
import '../classroom_detail_provider.dart';

/// One learning unit as this classroom runs it.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.activity, this.onTap});

  final Activity activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unit = activity.unit;

    // The classroom references a unit whose document is missing. Say so rather
    // than rendering a row that does nothing when tapped.
    if (unit == null) {
      return TcStatusBanner(
        type: TcMsgType.info,
        message: 'classroom.missing_unit'.tr(),
      );
    }

    final meta = [
      unit.subjectName,
      if (unit.stepCount != null)
        'classroom.steps_count'.tr(args: ['${unit.stepCount}']),
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
              const TcIconTile(icon: Icons.science_outlined),
              SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle,
                    ),
                    if (unit.shortDescription != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        unit.shortDescription!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption,
                      ),
                    ],
                    if (meta.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(meta, style: AppTypography.tiny),
                    ],
                    if (unit.type != null) ...[
                      SizedBox(height: AppDimensions.spacing8),
                      TcChip(label: unit.type!, color: AppColors.ispfTeal),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 22.r, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
