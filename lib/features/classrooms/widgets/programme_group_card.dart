import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// A programme, and the activities it runs in this classroom, in one card that
/// opens and closes.
///
/// EXPANDABLE, because the activity cards below are tall ones with photographs
/// in them. A classroom running three programmes of four activities used to be
/// twelve full-height cards in a flat list, and finding the programme you teach
/// on a Tuesday meant scrolling past two you do not. Collapsed, the same
/// classroom is three headings on one screen.
///
/// THE COUNT IS THE POINT OF THE COLLAPSED STATE. "4 LUs" is what makes a shut
/// card informative rather than merely shut, and it is why the count sits in
/// the header rather than inside the body it summarises.
class ProgrammeGroupCard extends StatelessWidget {
  const ProgrammeGroupCard({
    super.key,
    required this.title,
    required this.activityCount,
    required this.expanded,
    required this.onToggle,
    required this.activities,
    this.footer,
  });

  final String title;
  final int activityCount;
  final bool expanded;
  final VoidCallback onToggle;

  /// The activity cards. Built by the caller and passed in, so this widget
  /// knows nothing about learning units and can be exercised on its own.
  ///
  /// NOT NAMED `children`, deliberately. Flutter's lint reserves that name for
  /// the last argument of a widget constructor, and this one has a `footer`
  /// after it that reads better where it is.
  final List<Widget> activities;

  /// Shown under [activities] when open. The classroom screen puts the route to
  /// the programme's own page here.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusCard),
              // Square at the bottom only while open, so the ripple does not
              // round off against the activities below it.
              bottom: Radius.circular(expanded ? 0 : AppDimensions.radiusCard),
            ),
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.spacing12),
              child: Row(
                children: [
                  // A HALF TURN, not two different glyphs. The arrow points at
                  // what the tap will do, and animating it makes clear that the
                  // rows appeared from this card rather than somewhere else.
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24.r,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacing8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle,
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacing8),
                  Text(
                    (activityCount == 1
                            ? 'classroom.lu_count_one'
                            : 'classroom.lu_count_many')
                        .tr(args: ['$activityCount']),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.spacing12,
                0,
                AppDimensions.spacing12,
                AppDimensions.spacing12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A programme with no activities says so, unlike the flat
                  // list this replaced, which simply showed nothing. Opening a
                  // card and finding it empty has to be distinguishable from
                  // opening one that failed to draw.
                  if (activities.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppDimensions.spacing12,
                      ),
                      child: Text(
                        'classroom.no_activities_yet'.tr(),
                        style: AppTypography.caption,
                      ),
                    )
                  else
                    for (var i = 0; i < activities.length; i++) ...[
                      if (i > 0) SizedBox(height: AppDimensions.spacing12),
                      activities[i],
                    ],
                  if (footer != null) ...[
                    SizedBox(height: AppDimensions.spacing12),
                    footer!,
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
