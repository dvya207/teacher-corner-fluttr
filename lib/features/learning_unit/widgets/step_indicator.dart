import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/models/workflow.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// Horizontal strip of the workflow's steps, in `sequenceNumber` order.
///
/// NUMBERED CIRCLES JOINED BY A LINE, not pills, and the difference is not
/// decoration. A row of pills reads as a set of filters, any of which might be
/// on. A stepper reads as a sequence with a position in it, which is what a
/// six-stage activity is and what a teacher needs to see at a glance: where
/// they are, and how much is left.
///
/// Selecting a step scrolls it into view. Without that, a six-step workflow on
/// a narrow phone can select step 5 while step 5 is off screen, so the teacher
/// sees the content change with nothing indicating where they are.
class StepIndicator extends StatefulWidget {
  const StepIndicator({
    super.key,
    required this.steps,
    required this.selectedIndex,
    required this.onSelected,
    this.doneStepIds = const {},
  });

  final List<WorkflowStep> steps;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Which steps are already recorded done, so a completed one reads as
  /// finished rather than merely unselected. Empty where progress cannot be
  /// recorded at all, which is the same as none being done.
  final Set<String> doneStepIds;

  @override
  State<StepIndicator> createState() => _StepIndicatorState();
}

class _StepIndicatorState extends State<StepIndicator> {
  final ScrollController _controller = ScrollController();
  List<GlobalKey> _keys = const [];

  @override
  void initState() {
    super.initState();
    _rebuildKeys();
    _scrollSelectedIntoView();
  }

  @override
  void didUpdateWidget(StepIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps.length != widget.steps.length) _rebuildKeys();
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.steps.length != widget.steps.length) {
      _scrollSelectedIntoView();
    }
  }

  void _rebuildKeys() {
    _keys = List.generate(widget.steps.length, (_) => GlobalKey());
  }

  void _scrollSelectedIntoView() {
    // After the frame, so the target actually has a position to scroll to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = widget.selectedIndex;
      if (index < 0 || index >= _keys.length) return;
      final context = _keys[index].currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        // Centred, so the neighbouring steps stay visible and the teacher can
        // see where they are in the sequence.
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: Row(
        // TOP-ALIGNED, so the circles line up with each other and with the
        // connectors regardless of whether a neighbour's label wraps to two
        // lines. Centre alignment made the row jump as the selection moved
        // between a one-line and a two-line label.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < widget.steps.length; i++) ...[
            if (i > 0) const _Connector(),
            _StepMarker(
              key: _keys[i],
              step: widget.steps[i],
              position: i + 1,
              selected: i == widget.selectedIndex,
              done: widget.doneStepIds.contains(widget.steps[i].workflowStepId),
              onTap: () => widget.onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

/// The line between two markers.
///
/// A FIXED WIDTH, not an Expanded. The strip scrolls horizontally, so there is
/// no bounded width to divide up; an Expanded in an unbounded Row throws.
class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Aligned with the vertical centre of the circle beside it, which is why
      // the offset is half the circle rather than a spacing token.
      padding: EdgeInsets.only(top: 21.r),
      child: Container(
        width: 34.w,
        height: 2,
        color: AppColors.borderLight,
      ),
    );
  }
}

/// One step: a numbered circle with its name beneath.
class _StepMarker extends StatelessWidget {
  const _StepMarker({
    super.key,
    required this.step,
    required this.position,
    required this.selected,
    required this.done,
    required this.onTap,
  });

  final WorkflowStep step;
  final int position;
  final bool selected;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // THREE STATES, NOT TWO. Selected is where the teacher is; done is where
    // they have been. Collapsing them would make a finished workflow look
    // identical to an untouched one everywhere except the current step.
    final Color fill;
    final Color border;
    final Color numberColour;
    if (selected) {
      fill = AppColors.navy;
      border = AppColors.navy;
      numberColour = AppColors.white;
    } else if (done) {
      fill = AppColors.success;
      border = AppColors.success;
      numberColour = AppColors.white;
    } else {
      fill = AppColors.white;
      border = AppColors.borderLight;
      numberColour = AppColors.textTertiary;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: Semantics(
        selected: selected,
        button: true,
        child: SizedBox(
          // A FIXED COLUMN WIDTH is what keeps the circles evenly spaced while
          // the labels under them differ wildly in length ("Pre-Test" against
          // "Make / Create (Core Execution)"). The label wraps inside it.
          width: 88.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42.r,
                height: 42.r,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 1.5),
                ),
                child: done && !selected
                    ? Icon(Icons.check_rounded,
                        size: 22.r, color: AppColors.white)
                    : Text(
                        '$position',
                        style: AppTypography.stepLabel.copyWith(
                          color: numberColour,
                        ),
                      ),
              ),
              SizedBox(height: AppDimensions.spacing8),
              Text(
                step.label,
                textAlign: TextAlign.center,
                // TWO LINES. Live step names run to "Make / Create (Core
                // Execution)", and one line of that is "Make / Create (Cor…",
                // which is not a name a teacher can pick out of six.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: selected ? AppColors.navy : AppColors.textTertiary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              if (step.canSkip) ...[
                SizedBox(height: 2.h),
                Text(
                  'lu.optional'.tr(),
                  style: AppTypography.tiny.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
