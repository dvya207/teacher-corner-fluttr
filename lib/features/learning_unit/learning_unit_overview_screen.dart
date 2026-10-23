import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models/workflow.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_chip.dart';
import '../../core/widgets/tc_empty_state.dart';
import '../../core/widgets/tc_hero_header.dart';
import '../../core/widgets/tc_loading.dart';
import '../../core/widgets/tc_section_label.dart';
import '../../core/widgets/tc_status_message.dart';
import '../auth/auth_provider.dart';
import 'learning_unit_provider.dart';
import 'widgets/activity_status_pill.dart';

/// What an activity IS, before a teacher starts running it.
///
/// SPLIT FROM THE PLAYER, which used to be the same screen. Opening an activity
/// dropped a teacher straight onto step one's content, so the two questions
/// they actually arrive with, "what is this" and "how long will it take", could
/// only be answered by paging through it. This screen answers both and then
/// hands over: the description, every step with its duration, and one button
/// into the step the teacher has not done yet.
class LearningUnitOverviewScreen extends StatefulWidget {
  const LearningUnitOverviewScreen({
    super.key,
    required this.learningUnitId,
    required this.workflowId,
    this.classroomId,
    this.programmeId,
    this.breadcrumb,
  });

  final String learningUnitId;
  final String workflowId;

  /// Progress is per classroom, so without one it can be shown but not
  /// recorded. See [LearningUnitProvider.canRecordProgress].
  final String? classroomId;
  final String? programmeId;

  /// "test school oak · ET · Science Grade ET", assembled by the caller from
  /// what it already knows. Passed in rather than read here: every part of it
  /// is on documents the classroom screen has in hand, and re-reading them to
  /// draw one line of grey text would be three round trips for a caption.
  final String? breadcrumb;

  @override
  State<LearningUnitOverviewScreen> createState() =>
      _LearningUnitOverviewScreenState();
}

class _LearningUnitOverviewScreenState
    extends State<LearningUnitOverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LearningUnitProvider>().load(
        learningUnitId: widget.learningUnitId,
        workflowId: widget.workflowId,
        uid: context.read<AuthProvider>().uid,
        classroomId: widget.classroomId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lu = context.watch<LearningUnitProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: switch (lu.status) {
        LearningUnitStatus.loading => TcLoading(message: 'common.loading'.tr()),
        LearningUnitStatus.notFound => TcEmptyState(
          icon: Icons.search_off_rounded,
          title: 'lu.not_found_title'.tr(),
          subtitle: 'lu.not_found_subtitle'.tr(),
        ),
        LearningUnitStatus.error => _ErrorState(
          messageKey: lu.errorKey ?? 'lu.error_generic',
          onRetry: lu.retry,
        ),
        LearningUnitStatus.loaded => _Loaded(
          lu: lu,
          breadcrumb: widget.breadcrumb,
          onOpenStep: _openStep,
        ),
      },
    );
  }

  void _openStep(int index) {
    final query = {
      'workflowId': widget.workflowId,
      if (widget.classroomId != null) 'classroomId': widget.classroomId!,
      if (widget.programmeId != null) 'programmeId': widget.programmeId!,
      'step': '$index',
    };
    context.push(
      Uri(
        path: '/lu/${widget.learningUnitId}/steps',
        queryParameters: query,
      ).toString(),
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
              title: 'lu.error_title'.tr(),
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
  const _Loaded({
    required this.lu,
    required this.breadcrumb,
    required this.onOpenStep,
  });

  final LearningUnitProvider lu;
  final String? breadcrumb;
  final void Function(int index) onOpenStep;

  @override
  Widget build(BuildContext context) {
    final unit = lu.unit!;
    final steps = lu.steps;

    // "TACtivity · 6 steps". The type is what a teacher calls this kind of
    // thing, and the count is the only number that predicts the lesson.
    final badge = [
      unit.type,
      if (steps.isNotEmpty)
        'classroom.steps_count'.tr(args: ['${steps.length}']),
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');

    // WHICHEVER FIELD HAS ONE, longest first. See LearningUnit.description:
    // live units carry five description fields and this screen used to read
    // two of them.
    final description = unit.description;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TcHeroHeader(
            showBack: true,
            onBack: () => context.pop(),
            breadcrumb: breadcrumb,
            title: unit.label,
            titleFontSize: 22,
            children: [
              if (badge.isNotEmpty)
                // Aligned left inside the slot, which the header otherwise
                // stretches to full width the way it does a stat tile.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.heroTileBg,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Text(
                      badge,
                      style: AppTypography.tiny.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          TcHeroSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (description != null && description.isNotEmpty) ...[
                  _AboutCard(type: unit.type, description: description),
                  SizedBox(height: AppDimensions.spacing16),
                ],
                if (steps.isEmpty)
                  TcEmptyState(
                    icon: Icons.list_alt_rounded,
                    title: 'lu.no_steps_title'.tr(),
                    subtitle: 'lu.no_steps_subtitle'.tr(),
                  )
                else ...[
                  TcSectionLabel(
                    'lu.steps'.tr(),
                    // The count doubles as the progress readout, so a teacher
                    // returning to a half-taught activity sees where they were
                    // before opening a single step.
                    trailing: lu.canRecordProgress
                        ? ActivityStatusPill(status: lu.progressStatus)
                        : null,
                  ),
                  SizedBox(height: AppDimensions.spacing8),
                  for (var i = 0; i < steps.length; i++) ...[
                    _StepRow(
                      step: steps[i],
                      number: i + 1,
                      done: lu.isStepDone(i),
                      onTap: () => onOpenStep(i),
                    ),
                    SizedBox(height: AppDimensions.spacing8),
                  ],
                  SizedBox(height: AppDimensions.spacing12),
                  TcButton(
                    // "Resume" whatever the state, matching the reference. It
                    // is honest for the common case and no worse than "Start"
                    // for a fresh one, whereas a label that changes underneath
                    // a teacher mid-term is a button they have to read twice.
                    label: 'lu.resume_activity'.tr(),
                    icon: Icons.play_arrow_rounded,
                    onPressed: () async => onOpenStep(lu.resumeIndex),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.type, required this.description});

  final String? type;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (type != null && type!.trim().isNotEmpty) ...[
            TcChip(label: type!, color: AppColors.skyBlue),
            SizedBox(height: AppDimensions.spacing12),
          ],
          Text(description, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

/// One step: its number or its tick, its name, and how long it takes.
///
/// NO "SKIPPABLE" LABEL. `canSkipWorkflowStep` is set on most steps in live
/// data, so the word appeared on nearly every row and distinguished nothing
/// while competing with the duration for the one line of space under the name.
/// The player's own step strip still marks an optional step, which is where a
/// teacher deciding whether to run one actually is.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.number,
    required this.done,
    required this.onTap,
  });

  final WorkflowStep step;
  final int number;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      // A DONE STEP IS TINTED, not greyed. Greying it out says "unavailable",
      // and a teacher rereading a step they have already run is the normal way
      // this screen gets used.
      color: done ? AppColors.skyBg : AppColors.white,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spacing12),
          child: Row(
            children: [
              _StepMarker(number: number, done: done),
              SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      step.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        if (step.durationMinutes != null) ...[
                          Icon(
                            Icons.timer_outlined,
                            size: 14.r,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'lu.duration'.tr(
                              args: ['${step.durationMinutes}'],
                            ),
                            style: AppTypography.tiny,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The leading circle: the step's number, or a tick once it is done.
class _StepMarker extends StatelessWidget {
  const _StepMarker({required this.number, required this.done});

  final int number;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28.r,
      height: 28.r,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? AppColors.skyBlue : AppColors.bg,
        shape: BoxShape.circle,
      ),
      child: done
          ? Icon(Icons.check_rounded, size: 16.r, color: AppColors.white)
          : Text(
              '$number',
              style: AppTypography.tiny.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
