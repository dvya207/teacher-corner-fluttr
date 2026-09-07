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
    // THE LABEL YIELDS, THE TRAILING DOES NOT. At the 1.3x font ceiling a
    // letter-spaced caps heading and its affordance no longer fit side by side
    // on a 360dp phone, and an unconstrained Row overflows to the right by
    // about 35px rather than giving way.
    //
    // The heading is the half that can afford to lose characters: it names a
    // section the rows beneath it already demonstrate, whereas "See all" is a
    // control, and a control clipped in half is one a teacher cannot read or
    // trust. So the label takes the remaining width and ellipsizes into it.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(letterSpacing: 1.2),
            ),
          ),
          SizedBox(width: 8.w),
          trailing!,
        ],
      ),
    );
  }
}
