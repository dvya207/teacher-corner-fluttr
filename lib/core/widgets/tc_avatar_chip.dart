import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The teacher's initials in a filled circle, top right of the dashboard.
///
/// TAPPABLE, and that is the point of it rather than decoration: it is the
/// shortest route to the profile from the screen a teacher lands on. The bottom
/// nav can get there too, which is fine — a frequently wanted destination
/// earning two routes is normal, and this one is where a teacher looks for
/// "me".
///
/// The tap target is the whole circle and is kept at [minTarget] even when the
/// circle is drawn smaller, because a 40px visual on a phone held one-handed
/// mid-class is not a comfortable target and the design's diameter is not the
/// same question as the touch area.
class TcAvatarChip extends StatelessWidget {
  const TcAvatarChip({
    super.key,
    required this.initials,
    this.onTap,
    this.diameter = 40,
    this.semanticLabel,
  });

  /// Already-computed initials. Uppercased here so a caller cannot make this the
  /// one place in the app that renders a lowercase avatar.
  final String initials;

  final VoidCallback? onTap;

  /// Design-spec diameter; scaled with `.r` at build time, never at static init.
  final double diameter;

  /// What a screen reader announces. Without it this reads as two letters, which
  /// tells someone nothing about where the tap goes.
  final String? semanticLabel;

  /// The floor on the touch area, independent of [diameter].
  static const double minTarget = 48;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: diameter.r,
      height: diameter.r,
      decoration: const BoxDecoration(
        color: AppColors.skyBlue,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        // Blank initials would render an empty circle, which reads as a loading
        // state rather than as an account. A single glyph is honest about
        // knowing nothing.
        initials.trim().isEmpty ? '?' : initials.trim().toUpperCase(),
        style: AppTypography.label.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(label: semanticLabel, child: circle);
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: minTarget.r,
          height: minTarget.r,
          child: Center(child: circle),
        ),
      ),
    );
  }
}
