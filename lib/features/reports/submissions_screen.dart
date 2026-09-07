import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_app_bar.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_empty_state.dart';
import '../../core/widgets/tc_loading.dart';
import 'submissions_provider.dart';

/// Level one of the Submissions report: the teacher's classrooms.
///
/// A CLASSROOM PER CARD, named as the teacher names it, with its institution
/// and its two counts underneath. The counts are what make the list navigable:
/// a teacher with eight classrooms is looking for the one they taught in this
/// week, and "4 programmes · 13 activities" distinguishes two classrooms both
/// called "7 A" better than their names do.
class SubmissionsScreen extends StatefulWidget {
  const SubmissionsScreen({super.key});

  @override
  State<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends State<SubmissionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SubmissionsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubmissionsProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TcAppBar(
        title: 'reports.submissions_title'.tr(),
        showBack: true,
      ),
      body: switch (provider.status) {
        SubmissionsStatus.loading => TcLoading(message: 'common.loading'.tr()),
        SubmissionsStatus.error => _Error(
          messageKey: provider.errorKey ?? 'reports.submissions_error',
          onRetry: provider.load,
        ),
        SubmissionsStatus.empty => TcEmptyState(
          icon: Icons.folder_off_outlined,
          title: 'reports.no_classrooms_title'.tr(),
          subtitle: 'reports.no_classrooms_subtitle'.tr(),
        ),
        SubmissionsStatus.loaded => ListView.separated(
          padding: EdgeInsets.all(AppDimensions.spacing16),
          itemCount: provider.classrooms.length,
          separatorBuilder: (_, _) => SizedBox(height: AppDimensions.spacing12),
          itemBuilder: (context, i) =>
              _ClassroomCard(item: provider.classrooms[i]),
        ),
      },
    );
  }
}

class _ClassroomCard extends StatelessWidget {
  const _ClassroomCard({required this.item});

  final ClassroomSubmissions item;

  @override
  Widget build(BuildContext context) {
    final classroom = item.classroom;
    final meta = [
      if ((classroom.institutionName ?? '').trim().isNotEmpty)
        classroom.institutionName!.trim(),
      'reports.programme_count'.plural(item.programmeCount),
      'reports.activity_count'.plural(item.activityCount),
    ].join(' · ');

    // NOTHING TO DRILL INTO WITH NO PROGRAMMES. The card still lists, because
    // its absence would read as the classroom not existing, but it does not
    // offer a tap that would open an empty picker.
    final enabled = item.programmeCount > 0;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: InkWell(
        onTap: enabled ? () => _openProgrammePicker(context) : null,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Container(
          padding: EdgeInsets.all(AppDimensions.spacing16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(color: AppColors.borderSubtle),
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
                      style: AppTypography.heading3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(meta, style: AppTypography.caption),
                  ],
                ),
              ),
              if (enabled)
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                  size: 22.r,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// A SHEET RATHER THAN A SCREEN for the programme choice, matching the
  /// reference. Picking a programme is a step on the way to the activities
  /// rather than a place a teacher stays, and a pushed screen they would have
  /// to back out of makes it feel like one.
  void _openProgrammePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusSheet),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(AppDimensions.spacing24),
              child: Text(
                'reports.choose_programme'.tr(),
                style: AppTypography.heading2,
              ),
            ),
            for (final programme in item.classroom.programmes)
              ListTile(
                title: Text(programme.label, style: AppTypography.bodyStrong),
                subtitle: Text(
                  'reports.activity_count'.plural(programme.workflows.length),
                  style: AppTypography.caption,
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                  size: 20.r,
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push(
                    '/reports/submissions/'
                    '${item.classroom.classroomId}/${programme.programmeId}',
                  );
                },
              ),
            SizedBox(height: AppDimensions.spacing16),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.messageKey, required this.onRetry});

  final String messageKey;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              messageKey.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            SizedBox(height: AppDimensions.spacing24),
            TcButton(label: 'common.retry'.tr(), onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
