import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/models/workflow.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_app_bar.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_empty_state.dart';
import '../../core/widgets/tc_loading.dart';
import '../../core/widgets/tc_status_message.dart';
import 'learning_unit_provider.dart';
import 'widgets/content_pane.dart';
import 'widgets/step_indicator.dart';

/// One activity, walked step by step. Full screen and outside the bottom-nav
/// shell: a teacher in the middle of a step should not be one stray tap from
/// another tab.
class LearningUnitScreen extends StatefulWidget {
  const LearningUnitScreen({
    super.key,
    required this.learningUnitId,
    required this.workflowId,
  });

  final String learningUnitId;
  final String workflowId;

  @override
  State<LearningUnitScreen> createState() => _LearningUnitScreenState();
}

class _LearningUnitScreenState extends State<LearningUnitScreen> {
  /// Which content tab is showing, per step id.
  ///
  /// Keyed by step rather than a single index, so walking forward and back
  /// returns the teacher to the tab they were reading rather than resetting.
  final Map<String, int> _tabByStep = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LearningUnitProvider>().load(
        learningUnitId: widget.learningUnitId,
        workflowId: widget.workflowId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LearningUnitProvider>();
    final unit = provider.unit;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TcAppBar(title: unit?.label ?? 'lu.steps'.tr(), showBack: true),
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
  });

  final LearningUnitProvider provider;
  final Map<String, int> tabByStep;
  final void Function(String stepId, int index) onTabSelected;

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
        // Capped at 55% the content pane always keeps a usable share.
        final headerMax = constraints.maxHeight * 0.55;
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
                    ),
                    SizedBox(height: AppDimensions.spacing12),
                    _StepHeader(
                      step: step,
                      position: provider.selectedStepIndex + 1,
                      total: provider.steps.length,
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
                // IndexedStack, not a conditional child: every pane stays in
                // the tree, so switching tabs paints a different one rather
                // than building it from scratch and re-resolving its image.
                child: IndexedStack(
                  index: selectedTab,
                  sizing: StackFit.expand,
                  children: [
                    for (final content in contents)
                      ContentPane(
                        // Keyed by identity so a step change swaps panes rather
                        // than reusing the previous step's state.
                        key: ValueKey(
                          '${step.workflowStepId}:${content.contentName}',
                        ),
                        content: content,
                      ),
                  ],
                ),
              ),
            ],
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
    required this.position,
    required this.total,
  });

  final WorkflowStep step;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    final meta = [
      'lu.step_of'.tr(args: ['$position', '$total']),
      if (step.durationMinutes != null)
        'lu.duration'.tr(args: ['${step.durationMinutes}']),
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meta, style: AppTypography.tiny),
          SizedBox(height: 2.h),
          Text(step.label, style: AppTypography.heading3),
        ],
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing12,
      ),
      child: Row(
        children: [
          for (var i = 0; i < contents.length; i++) ...[
            if (i > 0) SizedBox(width: AppDimensions.spacing8),
            _Tab(
              label: contents[i].contentName ?? 'lu.document'.tr(),
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing12,
          vertical: AppDimensions.spacing8,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.skyBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: selected ? AppColors.skyBlue : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.skyBlue : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
