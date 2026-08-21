import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_typography.dart';

/// Letter-spaced caps section header — the mockup's "PROGRAMMES" /
/// "STUDENTS" / "SCHEDULE" labels. Optional [trailing] for the right-aligned
/// affordance ("4 LUs", "See all →").
class TcSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const TcSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      style: AppTypography.label.copyWith(letterSpacing: 1.2),
    );
    if (trailing == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: label,
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [label, trailing!],
      ),
    );
  }
}
