import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models/assignment.dart';
import '../../core/models/workflow.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_app_bar.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_empty_state.dart';
import '../../core/widgets/tc_loading.dart';
import '../../core/widgets/tc_status_message.dart';
import '../auth/auth_provider.dart';
import '../evidence/evidence_panel.dart';
import '../evidence/evidence_provider.dart';
import '../../core/services/evidence_storage.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/photo_picker.dart';
import '../quizzes/quiz_player_provider.dart';
import 'learning_unit_provider.dart';
import 'widgets/content_pane.dart';
import 'widgets/form_panel.dart';
import 'widgets/step_indicator.dart';

/// One activity, walked step by step. Full screen and outside the bottom-nav
/// shell: a teacher in the middle of a step should not be one stray tap from
/// another tab.
class LearningUnitScreen extends StatefulWidget {
  const LearningUnitScreen({
    super.key,
    required this.learningUnitId,
    required this.workflowId,
    this.classroomId,
    this.programmeId,
    this.initialStep,
    this.evidencePanelBuilder,
  });

  final String learningUnitId;
  final String workflowId;

  /// Needed to address the evidence document. Null when this screen was reached
  /// by a link that did not carry them.
  final String? classroomId;
  final String? programmeId;

  /// Which step to open on, from `?step=`. The overview screen sends the first
  /// one not yet done, so "Resume Activity" lands where the teacher stopped
  /// rather than back at the introduction.
  final int? initialStep;

  /// Injected by tests so the evidence pane can be exercised without Storage.
  final EvidencePanelBuilder? evidencePanelBuilder;

  @override
  State<LearningUnitScreen> createState() => _LearningUnitScreenState();
}

class _LearningUnitScreenState extends State<LearningUnitScreen> {
  /// Which content tab is showing, per step id.
  ///
  /// Keyed by step rather than a single index, so walking forward and back
  /// returns the teacher to the tab they were reading rather than resetting.
  final Map<String, int> _tabByStep = {};

  /// Answers submitted during this visit, by assignment id. Not a cache of
  /// what is stored: it exists so paging between steps does not blank a form a
  /// teacher has just sent.
  final Map<String, Map<String, Object?>> _formAnswers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final lu = context.read<LearningUnitProvider>();
      await lu.load(
        learningUnitId: widget.learningUnitId,
        workflowId: widget.workflowId,
        uid: context.mounted ? context.read<AuthProvider>().uid : null,
        classroomId: widget.classroomId,
      );
      // AFTER the load, because the step list does not exist before it and
      // selectStep silently ignores an index it cannot place.
      final step = widget.initialStep;
      if (step != null) lu.selectStep(step);
    });
  }

  /// Builds the feedback form for a FORM step.
  ///
  /// Refuses to SAVE rather than refuses to SHOW when the ids are missing. A
  /// teacher who opened the activity outside a classroom can still read what
  /// is being asked; they just cannot send it, and the panel says so. The
  /// evidence pane takes the opposite line because a photo saved against the
  /// wrong classroom is worse than one not saved at all, whereas a form that
  /// simply refuses to appear teaches nothing.
  Widget _buildForm(BuildContext context, Assignment assignment) {
    final uid = context.read<AuthProvider>().uid;
    final classroomId = widget.classroomId;
    final programmeId = widget.programmeId;
    final canSubmit =
        uid != null && classroomId != null && programmeId != null;

    return FormPanel(
      assignment: assignment,
      canSubmit: canSubmit,
      existingAnswers: _formAnswers[assignment.docId],
      onSubmit: (answers) async {
        if (!canSubmit) return false;
        try {
          await context.read<FirestoreService>().writeFormResponse(
            uid: uid,
            classroomId: classroomId,
            programmeId: programmeId,
            assignmentId: assignment.docId,
            answers: answers,
          );
          // Held so the panel reopens filled in when a teacher pages away and
          // back within the same visit.
          _formAnswers[assignment.docId] = answers;
          return true;
        } catch (e) {
          debugPrint('LearningUnitScreen: form save failed: $e');
          return false;
        }
      },
    );
  }

  /// Opens a quiz step in the player the Quizzes tab already uses.
  ///
  /// THE SAME PLAYER, not a second one. A quiz reached from a workflow step and
  /// the same quiz reached from the Quizzes tab are one assignment with one
  /// attempt allowance, and two players would be two places for that rule to
  /// drift apart.
  Future<void> _openQuiz(BuildContext context, Assignment assignment) async {
    final auth = context.read<AuthProvider>();
    final account = auth.account;
    final teacherDocId = account?.teaching?.docId;
    final uid = account?.uid;
    final classroomId = widget.classroomId;
    final programmeId = widget.programmeId;

    // NOWHERE TO WRITE, said before the quiz opens rather than after it is
    // answered. Losing a completed attempt to a permission the app already knew
    // about is the worse failure.
    //
    // TWO REFUSALS, NOT ONE. These were a single condition behind a single
    // message, and that was itself a bug: the two causes have nothing in
    // common, only one of them is the teacher's to fix, and collapsing them
    // meant the button appeared to do nothing at all. A teacher reporting
    // "the quiz will not open" gave no way to tell which had happened.
    //
    // NO TEACHER RECORD. The account is not linked to a `teachers` document,
    // so `teachers/{docId}/submissions` cannot be addressed and the deployed
    // rule would refuse it anyway: it grants on `teacherMeta.uid` of that very
    // document. Nothing in the app fixes this; the number has to be registered.
    if (account == null || teacherDocId == null || uid == null) {
      debugPrint(
        'LearningUnitScreen: quiz refused, account not linked. '
        'account=${account != null} teacherDocId=$teacherDocId uid=$uid',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('quizzes.no_teacher_record'.tr())));
      return;
    }

    // NO CLASSROOM. The account is fine; the activity was reached by a link
    // that did not carry the classroom and programme, so the attempt has
    // nowhere to be filed. Reopening it from the classroom fixes it, which is
    // what the message says. Same line the form panel takes for the same
    // reason.
    if (classroomId == null || programmeId == null) {
      debugPrint(
        'LearningUnitScreen: quiz refused, opened outside a classroom. '
        'classroomId=$classroomId programmeId=$programmeId',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('quizzes.no_classroom'.tr())));
      return;
    }

    await context.push(
      '/quizzes/play',
      extra: QuizPlayTarget(
        assignment: assignment,
        teacherDocId: teacherDocId,
        uid: uid,
        classroomId: classroomId,
        programmeId: programmeId,
      ),
    );
  }

  /// Builds the evidence pane for an upload assignment.
  ///
  /// Refuses rather than guesses when the ids that address the submission
  /// document are missing: a submission written under the wrong classroom or
  /// programme is worse than one not written at all.
  Widget _buildEvidence(BuildContext context, WorkflowStep step,
      WorkflowContent content) {
    final classroomId = widget.classroomId;
    final programmeId = widget.programmeId;
    final assignmentId = content.assignmentId ?? step.assignmentId;
    final uid = context.read<AuthProvider>().uid;

    if (classroomId == null ||
        classroomId.isEmpty ||
        programmeId == null ||
        programmeId.isEmpty ||
        assignmentId == null ||
        assignmentId.isEmpty ||
        uid == null ||
        uid.isEmpty) {
      return const EvidenceUnavailable();
    }

    final target = EvidenceTarget(
      classroomId: classroomId,
      programmeId: programmeId,
      learningUnitId: widget.learningUnitId,
      assignmentId: assignmentId,
      displayName: content.contentName,
    );

    final builder = widget.evidencePanelBuilder ?? _defaultEvidencePanel;
    return builder(context, target);
  }

  Widget _defaultEvidencePanel(BuildContext context, EvidenceTarget target) {
    final uid = context.read<AuthProvider>().uid!;
    return ChangeNotifierProvider<EvidenceProvider>(
      create: (ctx) => EvidenceProvider(
        firestore: ctx.read<FirestoreService>(),
        storage: FirebaseEvidenceStorage(),
        picker: ImagePickerPhotoPicker(),
        uid: uid,
        classroomId: target.classroomId,
        programmeId: target.programmeId,
        learningUnitId: target.learningUnitId,
        assignmentId: target.assignmentId,
        displayName: target.displayName,
      ),
      child: const EvidencePanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LearningUnitProvider>();
    final unit = provider.unit;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TcAppBar(
        title: unit?.label ?? 'lu.steps'.tr(),
        // THE PROGRESS READOUT GOES IN THE BAR, where it is visible from every
        // step and every tab. It was nowhere before: the overview screen shows
        // ticks and this screen showed none, so a teacher part-way through a
        // six-stage activity had to go back to find out how far they were.
        //
        // Only where progress can be recorded at all. Signed out or opened
        // outside a classroom, "0 / 6 stages completed" would be a permanent,
        // meaningless zero.
        subtitle: provider.status == LearningUnitStatus.loaded &&
                provider.canRecordProgress &&
                provider.steps.isNotEmpty
            ? 'lu.stages_completed'.tr(
                args: ['${provider.completedCount}', '${provider.steps.length}'],
              )
            : null,
        showBack: true,
      ),
      body: switch (provider.status) {
        LearningUnitStatus.loading => TcLoading(message: 'common.loading'.tr()),
        LearningUnitStatus.notFound => TcEmptyState(
          icon: Icons.search_off_rounded,
          title: 'lu.not_found_title'.tr(),
          subtitle: 'lu.not_found_subtitle'.tr(),
        ),
        LearningUnitStatus.error => _ErrorState(
          messageKey: provider.errorKey ?? 'lu.error_generic',
          onRetry: provider.retry,
        ),
        LearningUnitStatus.loaded => _Loaded(
          provider: provider,
          tabByStep: _tabByStep,
          onTabSelected: (stepId, index) =>
              setState(() => _tabByStep[stepId] = index),
          evidenceBuilder: _buildEvidence,
          quizOpener: _openQuiz,
          formBuilder: _buildForm,
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
    required this.provider,
    required this.tabByStep,
    required this.onTabSelected,
    required this.evidenceBuilder,
    required this.quizOpener,
    required this.formBuilder,
  });

  final LearningUnitProvider provider;
  final Map<String, int> tabByStep;
  final void Function(String stepId, int index) onTabSelected;
  final Widget Function(
    BuildContext context,
    WorkflowStep step,
    WorkflowContent content,
  ) evidenceBuilder;

  /// Passed down rather than called here, for the same reason as
  /// [evidenceBuilder]: it needs the screen's classroom and programme ids,
  /// which this widget was never given.
  final Future<void> Function(BuildContext context, Assignment assignment)
  quizOpener;

  /// Same reasoning as [evidenceBuilder]: the submission is addressed with the
  /// classroom and programme ids, which live on the screen.
  final Widget Function(BuildContext context, Assignment assignment)
  formBuilder;

  @override
  Widget build(BuildContext context) {
    if (provider.hasNoSteps) {
      return TcEmptyState(
        icon: Icons.list_alt_outlined,
        title: 'lu.no_steps_title'.tr(),
        subtitle: 'lu.no_steps_subtitle'.tr(),
      );
    }

    final step = provider.selectedStep!;
    final contents = step.contents;
    final selectedTab = (tabByStep[step.workflowStepId] ?? 0).clamp(
      0,
      _lastIndex(contents),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // The header block is bounded and scrollable rather than free to grow.
        // The design tokens scale against a 360-wide baseline, so in landscape
        // (800x360) every vertical measurement in here is ~2.2x too tall while
        // the available height collapses; unbounded, it overflowed by 325px.
        //
        // TWO CAPS, WHICHEVER IS TIGHTER, and the second one exists because the
        // fixed chrome below grew. 55% of the height is the share that keeps
        // the content pane usable on a phone held upright. It is not enough on
        // its own: in landscape 55% of 360 leaves less than the tabs, the Mark
        // as Done button and the step nav need between them, so the Expanded
        // content pane was squeezed to zero and the Column still overflowed by
        // 38px. The subtraction reserves what that chrome actually costs plus a
        // readable strip of content, and wins wherever the viewport is short.
        final headerMax = math.max(
          0.0,
          math.min(constraints.maxHeight * 0.55, constraints.maxHeight - 280),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: headerMax),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _About(provider: provider),
                    SizedBox(height: AppDimensions.spacing12),
                    StepIndicator(
                      steps: provider.steps,
                      selectedIndex: provider.selectedStepIndex,
                      onSelected: provider.selectStep,
                      // So a finished stage reads as finished rather than
                      // merely not-current.
                      doneStepIds: provider.completedStepIds,
                    ),
                    SizedBox(height: AppDimensions.spacing12),
                    // THE COUNT IS ALL-OR-NOTHING, deliberately. Progress is
                    // recorded per step, not per content, so a half-read step
                    // cannot be reported as "3 / 6" without inventing the 3.
                    // A done step shows all its contents done, which is true.
                    _StepHeader(
                      step: step,
                      doneContents: provider.isStepDone(
                        provider.selectedStepIndex,
                      )
                          ? contents.length
                          : 0,
                      totalContents: contents.length,
                    ),
                  ],
                ),
              ),
            ),
            if (contents.isEmpty)
              Expanded(
                child: TcEmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'lu.no_content_title'.tr(),
                  subtitle: 'lu.no_content_subtitle'.tr(),
                ),
              )
            else ...[
              _ContentTabs(
                contents: contents,
                selectedIndex: selectedTab,
                onSelected: (i) => onTabSelected(step.workflowStepId, i),
              ),
              Expanded(
                // IndexedStack, not a conditional child: a VISITED pane stays
                // in the tree, so coming back to a tab paints it rather than
                // rebuilding it and re-downloading its file.
                //
                // But IndexedStack BUILDS every child, and a pane now mounts a
                // PDF renderer or a video player, so each pane is told whether
                // it is the visible one and stays empty until it first is. See
                // ContentPane.isActive.
                child: IndexedStack(
                  index: selectedTab,
                  sizing: StackFit.expand,
                  children: [
                    for (final (i, content) in contents.indexed)
                      ContentPane(
                        isActive: i == selectedTab,
                        // Keyed by identity so a step change swaps panes rather
                        // than reusing the previous step's state.
                        key: ValueKey(
                          '${step.workflowStepId}:${content.contentName}',
                        ),
                        content: content,
                        // Resolved from learningUnitResources, because the
                        // step's own resourcePath is empty in live data.
                        resolvedPath: provider.resolvedPathFor(content),
                        // The unit's free-form extras, for the slot that lists
                        // them. Empty for every other content.
                        additionalResources: provider.additionalResourcesFor(
                          content,
                        ),
                        assignment: provider.assignmentFor(content),
                        onOpenQuiz: content.isQuizAssignment
                            ? (a) => quizOpener(context, a)
                            : null,
                        formBuilder: content.isFormAssignment
                            ? formBuilder
                            : null,
                        // Only for a content whose assignment could not be
                        // READ. A deleted one is not worth a Retry.
                        loadFailed: provider.assignmentsFailed,
                        reloading: provider.isReloadingAssignments,
                        onRetryLoad: provider.reloadAssignments,
                        evidenceBuilder: content.isUploadAssignment
                            ? (ctx) => evidenceBuilder(ctx, step, content)
                            : null,
                      ),
                  ],
                ),
              ),
            ],
            // THE ONLY WAY PROGRESS IS EVER MADE, which is why it sits outside
            // the tabs: a step is done when the teacher has run it, not when
            // they have looked at one of its content panes.
            //
            // Hidden entirely when progress cannot be recorded (signed out, or
            // opened outside a classroom) rather than shown disabled: a button
            // that never works is worse than no button, and the overview screen
            // above already omits its own progress readout in that case.
            if (provider.canRecordProgress)
              _MarkDoneBar(provider: provider),
            // MOVING BETWEEN STEPS WITHOUT AIMING AT A CIRCLE. The stepper is
            // the only way to change step otherwise, and its circles are 42dp
            // targets that scroll: fine for jumping to a known stage, poor for
            // "the next one", which is what a teacher does five times per
            // activity.
            _StepNav(provider: provider),
          ],
        );
      },
    );
  }

  static int _lastIndex(List<WorkflowContent> contents) =>
      contents.isEmpty ? 0 : contents.length - 1;
}

class _About extends StatelessWidget {
  const _About({required this.provider});

  final LearningUnitProvider provider;

  @override
  Widget build(BuildContext context) {
    final unit = provider.unit!;
    final description = unit.shortDescription ?? unit.longDescription;
    if (description == null || description.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.spacing16,
        AppDimensions.spacing12,
        AppDimensions.spacing16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('lu.about'.tr(), style: AppTypography.label),
          SizedBox(height: 4.h),
          Text(
            description,
            // Capped, because this block is chrome above the step strip and the
            // steps are what the teacher came for.
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.doneContents,
    required this.totalContents,
  });

  final WorkflowStep step;

  /// How many of this step's contents the teacher has got through.
  ///
  /// WHICH IS NOT TRACKED PER CONTENT. This app records progress per STEP, so
  /// the only honest reading of "0 / 6" for the current step is 0 until the
  /// step is done and all of them after. Reporting a number it does not have
  /// would be a fiction; see the note at the call site.
  final int doneContents;
  final int totalContents;

  @override
  Widget build(BuildContext context) {
    // THE NAME AND THE NUMBERS SIDE BY SIDE WHERE THEY FIT, and stacked where
    // they do not. The step number used to lead this block, above the name in
    // small grey text, and it is the one fact the stepper directly above
    // already shows. What belongs here is what the stepper cannot fit: how
    // long the step takes and how much of it is done.
    //
    // A WRAP, NOT A ROW, and the repo's own font-scale test is why. "Activity
    // Demonstration & Preparation" beside "10 min · 0 / 6 completed" fits a
    // 360dp phone at the default text size and overflows it by 23px at the
    // clamped maximum, where the meta alone is wider than the screen. A Row
    // cannot express "beside it, or under it" and a Column gives up the layout
    // even where there is room.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppDimensions.spacing12,
          runSpacing: 4.h,
          children: [
            ConstrainedBox(
              // Full width available, so a long name takes the line to itself
              // and pushes the meta onto the next run. A short one leaves room
              // beside it and the meta sits there.
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Text(
                step.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle,
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              // TEXT.RICH RATHER THAN A ROW OF WIDGETS, so the meta can wrap
              // inside itself at the largest font scale instead of overflowing
              // whatever it is put in. The clock is a WidgetSpan for the same
              // reason: it flows with the text.
              child: Text.rich(
                TextSpan(
                  children: [
                    if (step.durationMinutes != null) ...[
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: EdgeInsets.only(right: 4.w),
                          child: Icon(
                            Icons.timer_outlined,
                            size: 14.r,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      TextSpan(
                        text: 'lu.duration'.tr(
                          args: ['${step.durationMinutes}'],
                        ),
                      ),
                      const TextSpan(text: '  ·  '),
                    ],
                    TextSpan(
                      text: 'lu.contents_done'.tr(
                        args: ['$doneContents', '$totalContents'],
                      ),
                      style: AppTypography.tiny.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                style: AppTypography.tiny,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentTabs extends StatelessWidget {
  const _ContentTabs({
    required this.contents,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<WorkflowContent> contents;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // A HAIRLINE UNDER THE WHOLE STRIP, which the active tab's own thicker
      // rule sits on top of. Without it the underline floats with nothing to
      // read it against and the tabs stop looking like tabs.
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacing8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < contents.length; i++)
              _Tab(
                label: contents[i].contentName ?? 'lu.document'.tr(),
                icon: _iconFor(contents[i]),
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
          ],
        ),
      ),
    );
  }

  /// The glyph for one tab, so a teacher can find the video among four
  /// documents without reading five labels.
  ///
  /// FROM THE CONTENT'S ROLE, not from the resolved file. This is the one place
  /// the slot's own words are the right source: the tab is named and ordered by
  /// the workflow author, and an assignment tab has no file to inspect at all.
  /// What the pane shows inside is still decided from the file itself.
  static IconData _iconFor(WorkflowContent content) {
    if (content.isUploadAssignment) return Icons.file_upload_outlined;
    if (content.isQuizAssignment) return Icons.quiz_outlined;
    if (content.isFormAssignment) return Icons.fact_check_outlined;

    final kind = '${content.contentCategory ?? ''} '
            '${content.contentSubCategory ?? ''} '
            '${content.contentType ?? ''}'
        .toLowerCase();
    if (kind.contains('video') || kind.contains('reel')) {
      return Icons.play_circle_outline_rounded;
    }
    return Icons.description_outlined;
  }
}

/// One content tab: its glyph, its name, and a rule under the active one.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = selected ? AppColors.skyBlue : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Semantics(
        selected: selected,
        button: true,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing12,
            vertical: AppDimensions.spacing8,
          ),
          decoration: BoxDecoration(
            border: Border(
              // THE INDICATOR, and it is drawn on every tab rather than only
              // the active one. An inactive tab gets a transparent rule of the
              // same thickness, so selecting a tab does not shift the whole
              // strip up by three pixels.
              bottom: BorderSide(
                width: 3,
                color: selected ? AppColors.skyBlue : Colors.transparent,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22.r, color: colour),
              SizedBox(height: 4.h),
              ConstrainedBox(
                // Bounded so a long name wraps rather than making one tab as
                // wide as the screen. The strip scrolls, so several such tabs
                // are fine; one enormous one is not.
                constraints: BoxConstraints(maxWidth: 120.w),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: colour,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Step 1 of 6", with Back and Next either side of it.
///
/// PREVIOUS IS AN ICON AND NEXT IS A BUTTON, because they are not equally
/// likely. A teacher runs an activity forwards; going back a stage happens, but
/// giving it the same weight as Next would put two filled buttons at the bottom
/// of every step and make the common action harder to hit.
class _StepNav extends StatelessWidget {
  const _StepNav({required this.provider});

  final LearningUnitProvider provider;

  @override
  Widget build(BuildContext context) {
    final index = provider.selectedStepIndex;
    final total = provider.steps.length;
    final hasPrevious = index > 0;
    final hasNext = index < total - 1;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing12,
            vertical: AppDimensions.spacing8,
          ),
          child: Row(
            children: [
              // KEPT IN THE LAYOUT WHEN DISABLED, as an invisible box of the
              // same size. Dropping it on step 1 would slide the position text
              // sideways as the teacher moved off the first step.
              Opacity(
                opacity: hasPrevious ? 1 : 0,
                child: IconButton(
                  onPressed: hasPrevious
                      ? () => provider.selectStep(index - 1)
                      : null,
                  tooltip: 'lu.previous_step'.tr(),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: 20.r,
                    color: AppColors.skyBlue,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'lu.step_of'.tr(args: ['${index + 1}', '$total']),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall,
                ),
              ),
              if (hasNext)
                FilledButton.icon(
                  onPressed: () => provider.selectStep(index + 1),
                  iconAlignment: IconAlignment.end,
                  icon: Icon(Icons.arrow_forward_rounded, size: 18.r),
                  label: Text('lu.next_step'.tr()),
                )
              else
                // Symmetric with the hidden Back button, so the last step's
                // position text stays centred.
                SizedBox(width: 48.r),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Mark as Done", and the tick once it is.
///
/// A MINIMAL ADDITION TO THIS SCREEN, not a rebuild of it. The overview screen
/// shows ticks and a resume point, and without somewhere to record a step those
/// would be permanently empty. The fuller player in the reference (a stage
/// strip, a completed count in the app bar, previous and next) is a separate
/// piece of work; this is the one control that piece of work needs to already
/// exist.
class _MarkDoneBar extends StatelessWidget {
  const _MarkDoneBar({required this.provider});

  final LearningUnitProvider provider;

  @override
  Widget build(BuildContext context) {
    final index = provider.selectedStepIndex;
    final done = provider.isStepDone(index);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.spacing16,
        AppDimensions.spacing8,
        AppDimensions.spacing16,
        AppDimensions.spacing16,
      ),
      child: TcButton(
        label: done ? 'lu.step_completed'.tr() : 'lu.mark_as_done'.tr(),
        icon: done ? Icons.check_circle_rounded : Icons.check_rounded,
        // Green once done, so the primary weight on this screen always
        // belongs to the action still outstanding.
        variant: done ? TcButtonVariant.success : TcButtonVariant.primary,
        isLoading: provider.isSavingStep,
        onPressed: () async {
          final ok = await provider.setStepDone(index, done: !done);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('lu.step_save_failed'.tr())),
            );
          }
        },
      ),
    );
  }
}
