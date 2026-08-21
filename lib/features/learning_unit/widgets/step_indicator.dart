import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/models/workflow.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// Horizontal strip of the workflow's steps, in `sequenceNumber` order.
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
  });

  final List<WorkflowStep> steps;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

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
        children: [
          for (var i = 0; i < widget.steps.length; i++) ...[
            if (i > 0) SizedBox(width: AppDimensions.spacing8),
            _StepChip(
              key: _keys[i],
              step: widget.steps[i],
              position: i + 1,
              selected: i == widget.selectedIndex,
              onTap: () => widget.onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    super.key,
    required this.step,
    required this.position,
    required this.selected,
    required this.onTap,
  });

  final WorkflowStep step;
  final int position;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? AppColors.skyBlue : AppColors.white;
    final foreground = selected ? AppColors.white : AppColors.textSecondary;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        child: Container(
          // No maxWidth on the chip itself. It sits in a horizontally
          // scrollable Row, so it may be as wide as it needs; capping the whole
          // chip made its Row overflow by a few pixels once the system font
          // scale grew the number and the "Optional" label. Only the step NAME
          // is bounded, and it ellipsizes.
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing12,
            vertical: AppDimensions.spacing8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
            border: Border.all(
              color: selected ? AppColors.skyBlue : AppColors.borderLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$position',
                style: AppTypography.stepLabel.copyWith(color: foreground),
              ),
              SizedBox(width: AppDimensions.spacing8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 140.w),
                child: Text(
                  step.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(color: foreground),
                ),
              ),
              if (step.canSkip) ...[
                SizedBox(width: AppDimensions.spacing8),
                Text(
                  'lu.optional'.tr(),
                  style: AppTypography.tiny.copyWith(
                    color: selected
                        ? AppColors.white.withValues(alpha: 0.8)
                        : AppColors.textTertiary,
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
