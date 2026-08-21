import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class BreadcrumbSegment {
  final String label;
  final VoidCallback? onTap;

  const BreadcrumbSegment({required this.label, this.onTap});
}

/// Tappable breadcrumb strip for hero sections on gradient backgrounds.
/// Renders each segment with animated opacity on tap and an underline
/// affordance. The final segment (current page) is shown at reduced opacity
/// and is not tappable.
class TcBreadcrumb extends StatelessWidget {
  final List<BreadcrumbSegment> segments;
  final String separator;

  const TcBreadcrumb({
    super.key,
    required this.segments,
    this.separator = '›',
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      runSpacing: 2.h,
      children: [
        for (int i = 0; i < segments.length; i++) ...[
          _BreadcrumbSegmentWidget(
            segment: segments[i],
            isLast: i == segments.length - 1,
          ),
          if (i < segments.length - 1)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              child: Text(
                separator,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.white.withValues(alpha: 0.30),
                  fontSize: 11.sp,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _BreadcrumbSegmentWidget extends StatefulWidget {
  final BreadcrumbSegment segment;
  final bool isLast;

  const _BreadcrumbSegmentWidget({
    required this.segment,
    required this.isLast,
  });

  @override
  State<_BreadcrumbSegmentWidget> createState() =>
      _BreadcrumbSegmentWidgetState();
}

class _BreadcrumbSegmentWidgetState
    extends State<_BreadcrumbSegmentWidget> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isTappable = !widget.isLast && widget.segment.onTap != null;
    final opacity = _pressed ? 1.0 : (widget.isLast ? 0.45 : 0.75);

    return GestureDetector(
      onTap: isTappable ? widget.segment.onTap : null,
      onTapDown: isTappable ? (_) => setState(() => _pressed = true) : null,
      onTapUp: isTappable ? (_) => setState(() => _pressed = false) : null,
      onTapCancel:
          isTappable ? () => setState(() => _pressed = false) : null,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          decoration: isTappable
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.white.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                )
              : null,
          child: Text(
            widget.segment.label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.white,
              fontSize: 12.sp,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
