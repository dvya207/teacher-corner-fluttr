import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_empty_state.dart';
import '../../core/widgets/tc_hero_header.dart';
import '../../core/widgets/tc_hero_stat_tile.dart';
import '../../core/widgets/tc_loading.dart';
import '../../core/widgets/tc_section_label.dart';
import '../../core/widgets/tc_status_message.dart';
import '../auth/auth_provider.dart';
import 'classroom_detail_provider.dart';
import 'widgets/activity_card.dart';
import 'widgets/programme_group_card.dart';

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
      // The uid is for the progress read only. Signed out, the classroom still
      // loads and every activity reads "Not Started".
      context.read<ClassroomDetailProvider>().load(
        widget.classroomId,
        uid: context.read<AuthProvider>().uid,
      );
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

class _Loaded extends StatefulWidget {
  const _Loaded({required this.detail, required this.classroomId});

  final ClassroomDetailProvider detail;
  final String classroomId;

  @override
  State<_Loaded> createState() => _LoadedState();
}

class _LoadedState extends State<_Loaded> {
  /// Which programmes are open, by id.
  ///
  /// HELD BY THE SCREEN, not by the provider. It is view state: it survives a
  /// scroll, and it should not survive leaving the classroom and coming back,
  /// which is exactly the lifetime of this widget.
  final Set<String> _open = {};
  bool _seeded = false;

  /// The first programme opens itself.
  ///
  /// A screen of shut cards gives a teacher nothing to read and one more tap to
  /// make before they see anything. Most classrooms here run one programme, so
  /// for most teachers this is simply the screen already open.
  void _seed(List<ProgrammeActivities> programmes) {
    if (_seeded || programmes.isEmpty) return;
    _seeded = true;
    _open.add(programmes.first.programme.programmeId);
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final classroom = detail.classroom!;
    _seed(detail.programmes);

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
                        _ProgrammeSection(
                          entry: entry,
                          classroomId: widget.classroomId,
                          classroomName: classroom.displayName,
                          expanded: _open.contains(
                            entry.programme.programmeId,
                          ),
                          onToggle: () => setState(() {
                            final id = entry.programme.programmeId;
                            if (!_open.remove(id)) _open.add(id);
                          }),
                        ),
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

/// One programme's card, and the activities inside it.
class _ProgrammeSection extends StatelessWidget {
  const _ProgrammeSection({
    required this.entry,
    required this.classroomId,
    required this.classroomName,
    required this.expanded,
    required this.onToggle,
  });

  final ProgrammeActivities entry;
  final String classroomId;
  final String classroomName;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ProgrammeGroupCard(
      // Never blank and never "null": falls back to the id, which at least
      // identifies which programme this is.
      title: entry.programme.label,
      activityCount: entry.activities.length,
      expanded: expanded,
      onToggle: onToggle,
      activities: [
        for (final activity in entry.activities)
          ActivityCard(
            activity: activity,
            onTap: activity.unit == null
                ? null
                // The workflow id travels with the tap. It is a property of
                // THIS classroom's binding, so the learning unit screen cannot
                // look it up from the unit alone.
                : () => context.push(
                    '/lu/${activity.learningUnitId}'
                    '?classroomId=$classroomId'
                    '&programmeId=${entry.programme.programmeId}'
                    '&workflowId=${activity.workflowId}'
                    '&classroomName=${Uri.encodeComponent(classroomName)}'
                    '&programmeName='
                    '${Uri.encodeComponent(entry.programme.label)}',
                  ),
          ),
      ],
      // The programme's own catalogue page, kept reachable now that the header
      // row toggles instead of navigating. At the bottom because the
      // activities are what a teacher opened the card for; the programme's
      // description and grades are the rarer errand.
      footer: _ProgrammeDetailLink(
        onTap: () => context.push(
          '/classrooms/$classroomId/programmes/'
          '${entry.programme.programmeId}'
          '?classroomName=${Uri.encodeComponent(classroomName)}',
        ),
      ),
    );
  }
}

class _ProgrammeDetailLink extends StatelessWidget {
  const _ProgrammeDetailLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimensions.spacing8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Flexible, because this label is a sentence in every language and
            // a long one ("View programme details") already overflows a card
            // indented inside the classroom sheet. The chevron keeps its size:
            // it is the part that says the row goes somewhere.
            Flexible(
              child: Text(
                'programme.view_details'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.label.copyWith(color: AppColors.skyBlue),
              ),
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.chevron_right_rounded,
              size: 18.r,
              color: AppColors.skyBlue,
            ),
          ],
        ),
      ),
    );
  }
}
