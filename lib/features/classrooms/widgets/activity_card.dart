import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/services/storage_file_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tc_chip.dart';
import '../../../core/widgets/tc_storage_image.dart';
import '../../../core/widgets/tc_status_message.dart';
import '../../learning_unit/widgets/activity_status_pill.dart';
import '../classroom_detail_provider.dart';

/// One learning unit as this classroom runs it.
///
/// A TALL CARD WITH THE PICTURE IN IT, not a list row with a thumbnail. These
/// activities are physical things a class builds, and the photograph is how a
/// teacher recognises "the one with the magnets" without reading a word. It is
/// the only screen in the app where an image earns that much height.
///
/// THE STATUS APPEARS TWICE, top and bottom, which is deliberate rather than an
/// oversight: the top pill is read while scanning down a column of pictures,
/// the bottom one while reaching for "View Activity", and a teacher doing the
/// second should not have to look back up to check they are resuming the right
/// thing.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.imageSource,
  });

  final Activity activity;
  final VoidCallback? onTap;

  /// Injected by tests so a card can be rendered without Firebase Storage.
  final StorageFileSource? imageSource;

  @override
  Widget build(BuildContext context) {
    final unit = activity.unit;

    // The classroom references a unit whose document is missing. Say so rather
    // than rendering a card that does nothing when tapped.
    if (unit == null) {
      return TcStatusBanner(
        type: TcMsgType.info,
        message: 'classroom.missing_unit'.tr(),
      );
    }

    final subject = unit.subjectName?.trim() ?? '';

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spacing12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // NO Spacer IN THESE ROWS, and the reason is worth recording
              // because it looked right and read wrong. A Spacer is a flex
              // child, so pairing one with two Flexible children split the
              // free width three ways and left the status pill about 109dp to
              // render "Not Started" in. It ellipsized to "Not Sta..." on a
              // perfectly ordinary phone. spaceBetween pushes the two apart
              // without competing with them for room.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (subject.isNotEmpty)
                    Flexible(
                      child: TcChip(label: subject, color: AppColors.skyBlue),
                    )
                  else
                    const SizedBox.shrink(),
                  SizedBox(width: AppDimensions.spacing8),
                  Flexible(child: ActivityStatusPill(status: activity.status)),
                ],
              ),
              SizedBox(height: AppDimensions.spacing12),
              // learningUnitPreviewImage is a Storage PATH. TcStorageImage
              // checks the file cache for that path before resolving any
              // download URL, so a list of cards does not cost one round trip
              // per card on every scroll.
              //
              // A FIXED HEIGHT, not an aspect ratio. These photographs are not
              // all the same shape, and a row of cards whose heights follow
              // their images reads as a broken layout rather than a gallery.
              if (unit.previewImagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusInput,
                  ),
                  child: TcStorageImage(
                    storagePath: unit.previewImagePath,
                    width: double.infinity,
                    height: 150.h,
                    source: imageSource,
                  ),
                ),
              if (unit.previewImagePath != null)
                SizedBox(height: AppDimensions.spacing12),
              Text(
                unit.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle,
              ),
              if (unit.stepCount != null) ...[
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(
                      Icons.list_alt_rounded,
                      size: 15.r,
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(width: 6.w),
                    Flexible(
                      child: Text(
                        'classroom.steps_count'.tr(args: ['${unit.stepCount}']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption,
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: AppDimensions.spacing12),
              Divider(height: 1, color: AppColors.bg),
              SizedBox(height: AppDimensions.spacing8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: ActivityStatusPill(status: activity.status)),
                  SizedBox(width: AppDimensions.spacing8),
                  // TEXT, NOT A BUTTON. The whole card is already the tap
                  // target; a filled button inside it would offer a second,
                  // smaller version of the same action and invite a teacher to
                  // aim for it.
                  //
                  // The label and its arrow are ONE flex child, so the arrow
                  // travels with the words instead of being stranded at the
                  // right edge when the label shortens.
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'lu.view_activity'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: AppTypography.label.copyWith(
                              color: AppColors.skyBlue,
                            ),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16.r,
                          color: AppColors.skyBlue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
