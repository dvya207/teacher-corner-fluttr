import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_empty_state.dart';
import '../../core/widgets/tc_hero_header.dart';
import '../../core/widgets/tc_hero_stat_tile.dart';
import '../../core/widgets/tc_loading.dart';
import '../../core/widgets/tc_section_label.dart';
import '../../core/widgets/tc_status_message.dart';
import 'classroom_detail_provider.dart';
import 'widgets/activity_card.dart';
import 'widgets/programme_card.dart';

/// One classroom: its programmes, and the learning units within each.
class ClassroomDetailScreen extends StatefulWidget {
  const ClassroomDetailScreen({super.key, required this.classroomId});

  final String classroomId;

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClassroomDetailProvider>().load(widget.classroomId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<ClassroomDetailProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: switch (detail.status) {
        ClassroomDetailStatus.loading =>
          TcLoading(message: 'common.loading'.tr()),
        ClassroomDetailStatus.notFound => TcEmptyState(
            icon: Icons.search_off_rounded,
            title: 'classroom.not_found_title'.tr(),
            subtitle: 'classroom.not_found_subtitle'.tr(),
          ),
        ClassroomDetailStatus.error => _ErrorState(
            messageKey: detail.errorKey ?? 'classroom.error_generic',
            onRetry: detail.retry,
          ),
        ClassroomDetailStatus.loaded => _Loaded(
            detail: detail,
            classroomId: widget.classroomId,
          ),
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.messageKey, required this.onRetry});

  final String messageKey;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TcStatusBanner(
              type: TcMsgType.error,
              title: 'classroom.error_title'.tr(),
              message: messageKey.tr(),
            ),
            SizedBox(height: AppDimensions.spacing24),
            TcButton(label: 'common.retry'.tr(), onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.detail, required this.classroomId});

  final ClassroomDetailProvider detail;
  final String classroomId;

  @override
  Widget build(BuildContext context) {
    final classroom = detail.classroom!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TcHeroHeader(
            showBack: true,
            onBack: () => context.pop(),
            overline: classroom.institutionName,
            title: classroom.displayName,
            subtitle: classroom.gradeSectionLabel,
            children: [
              // Omitted when unknown rather than shown as zero: a missing count
              // is a statement about our read, not about the classroom.
              if (classroom.studentCounter != null)
                TcHeroStatTile(
                  value: '${classroom.studentCounter}',
                  label: 'classroom.stat_students'.tr(),
                ),
              TcHeroStatTile(
                value: '${detail.programmes.length}',
                label: 'classroom.stat_programmes'.tr(),
              ),
            ],
          ),
          TcHeroSheet(
            child: detail.hasNoProgrammes
                ? TcEmptyState(
                    icon: Icons.folder_outlined,
                    title: 'classroom.no_programmes_title'.tr(),
                    subtitle: 'classroom.no_programmes_subtitle'.tr(),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TcSectionLabel('classroom.programmes_label'.tr()),
                      SizedBox(height: AppDimensions.spacing12),
                      for (final entry in detail.programmes) ...[
                        // The programme itself is now the tappable row, so the
                        // flow reaches its catalogue document. Its activities,
                        // when there are any, are listed beneath it.
                        ProgrammeCard(
                          programme: entry.programme,
                          onTap: () => context.push(
                            '/classrooms/$classroomId/programmes/'
                            '${entry.programme.programmeId}'
                            '?classroomName='
                            '${Uri.encodeComponent(classroom.displayName)}',
                          ),
                        ),
                        SizedBox(height: AppDimensions.spacing12),
                        // No empty-activities banner. learningUnits has no
                        // documents and workflows does not exist in this
                        // database, so every classroom would carry an identical
                        // "nothing here" line under every programme. When the
                        // bindings arrive, the cards below appear on their own.
                        if (entry.activities.isNotEmpty)
                          for (final activity in entry.activities) ...[
                            ActivityCard(
                              activity: activity,
                              onTap: activity.unit == null
                                  ? null
                                  // The workflow id travels with the tap. It is
                                  // a property of THIS classroom's binding, so
                                  // the learning unit screen cannot look it up
                                  // from the unit alone.
                                  : () => context.push(
                                        '/lu/${activity.learningUnitId}'
                                        '?classroomId=$classroomId'
                                        '&programmeId='
                                        '${entry.programme.programmeId}'
                                        '&workflowId=${activity.workflowId}',
                                      ),
                            ),
                            SizedBox(height: AppDimensions.spacing12),
                          ],
                        SizedBox(height: AppDimensions.spacing12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
