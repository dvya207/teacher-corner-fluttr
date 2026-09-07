import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/models/submission_report.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_app_bar.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_empty_state.dart';
import '../../core/widgets/tc_loading.dart';
import 'submissions_provider.dart';
import 'widgets/submission_detail_sheet.dart';

/// Level two of the Submissions report: one programme's activities, each with
/// the people who could have submitted against it.
///
/// ONE PERSON ROW, AND IT IS THE SIGNED-IN TEACHER. The reference app lists
/// several names per activity because production keeps submissions in a shared
/// top-level collection. This app writes them under `users/{uid}/`, which the
/// deployed rules grant to that uid alone, so the only record readable here is
/// the teacher's own. The row is labelled "Teacher (you)" for that reason, and
/// the screen says so at the top rather than implying the list is everybody.
class SubmissionActivitiesScreen extends StatefulWidget {
  const SubmissionActivitiesScreen({super.key});

  @override
  State<SubmissionActivitiesScreen> createState() =>
      _SubmissionActivitiesScreenState();
}

class _SubmissionActivitiesScreenState
    extends State<SubmissionActivitiesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ActivitySubmissionsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ActivitySubmissionsProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TcAppBar(
        title: 'reports.submissions_title'.tr(),
        subtitle: provider.programmeName,
        showBack: true,
      ),
      body: switch (provider.status) {
        SubmissionsStatus.loading => TcLoading(message: 'common.loading'.tr()),
        SubmissionsStatus.error => Center(
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.spacing24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 44.r,
                  color: AppColors.textTertiary,
                ),
                SizedBox(height: AppDimensions.spacing16),
                Text(
                  (provider.errorKey ?? 'reports.submissions_error').tr(),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium,
                ),
                SizedBox(height: AppDimensions.spacing24),
                TcButton(
                  label: 'common.retry'.tr(),
                  onPressed: provider.load,
                ),
              ],
            ),
          ),
        ),
        SubmissionsStatus.empty => TcEmptyState(
          icon: Icons.inbox_outlined,
          title: 'reports.no_activities_title'.tr(),
          subtitle: 'reports.no_activities_subtitle'.tr(),
        ),
        SubmissionsStatus.loaded => ListView.separated(
          padding: EdgeInsets.all(AppDimensions.spacing16),
          itemCount: provider.activities.length + 1,
          separatorBuilder: (_, _) => SizedBox(height: AppDimensions.spacing12),
          itemBuilder: (context, i) {
            if (i == 0) return const _OwnRecordOnlyNote();
            return _ActivityCard(activity: provider.activities[i - 1]);
          },
        ),
      },
    );
  }
}

/// Says whose record this is, once, at the top.
///
/// ON THE SCREEN RATHER THAN ONLY IN A COMMENT, because the difference is
/// invisible otherwise: a list showing one name looks like a classroom with one
/// teacher, not like a report that can only see one.
class _OwnRecordOnlyNote extends StatelessWidget {
  const _OwnRecordOnlyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.searchFill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18.r,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: AppDimensions.spacing8),
          Expanded(
            child: Text(
              'reports.own_record_only'.tr(),
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// One activity: its name, how much of it has been handed in, and the person
/// row that opens the detail.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final ActivitySubmissions activity;

  @override
  Widget build(BuildContext context) {
    final submitted = activity.hasAnySubmission;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(AppDimensions.spacing16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    activity.label,
                    style: AppTypography.cardTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: AppDimensions.spacing8),
                // "1 of 4": how many of the activity's blocks have content.
                // Counted from the workflow's own assignments, so an activity
                // with nothing to submit reads "0 of 0" rather than looking
                // incomplete.
                Text(
                  'reports.of_count'.tr(
                    args: ['${activity.submittedCount}', '${activity.totalCount}'],
                  ),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),
          InkWell(
            onTap: activity.blocks.isEmpty
                ? null
                : () => showSubmissionDetailSheet(
                    context,
                    activityLabel: activity.label,
                    blocks: activity.blocks,
                  ),
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.spacing16),
              child: Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 20.r,
                    color: AppColors.skyBlue,
                  ),
                  SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: Text(
                      'reports.teacher_you'.tr(),
                      style: AppTypography.bodyStrong,
                    ),
                  ),
                  Text(
                    submitted
                        ? 'reports.submitted'.tr()
                        : 'reports.not_submitted'.tr(),
                    style: AppTypography.caption.copyWith(
                      color: submitted
                          ? AppColors.success
                          : AppColors.textTertiary,
                      fontWeight: submitted ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  if (activity.blocks.isNotEmpty) ...[
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.chevron_right,
                      size: 20.r,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
