import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// One topic in Help & Guide: a tinted title band over numbered steps.
///
/// THE ACCENT COLOUR CARRIES MEANING, which is why it is a required argument
/// rather than a decorative default. The design groups the topics by what they
/// are about — getting around the app, submitting, reviewing, support — and the
/// tint is what makes that grouping visible while scrolling past. Picking one at
/// random would leave the colour looking like variety for its own sake.
///
/// The steps are NUMBERED because they are a sequence: each one is an
/// instruction that only makes sense after the one above it. That is exactly the
/// case where numbering encodes something true rather than decorating a list.
class GuideCard extends StatelessWidget {
  const GuideCard({
    super.key,
    required this.icon,
    required this.title,
    required this.steps,
    required this.accent,
  });

  final IconData icon;
  final String title;

  /// In order. The index becomes the badge number, so a caller cannot number
  /// them inconsistently with their position.
  final List<String> steps;

  /// Tints the band, the icon, the title and the step badges. One colour, four
  /// uses, so a card cannot end up half one family and half another.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      // clipBehavior, so the tinted band's own corners follow the card's rather
      // than squaring off inside them.
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            // A wash of the accent rather than the accent itself: the title has
            // to stay readable on it, and a saturated band would make the card
            // read as a warning.
            color: accent.withValues(alpha: 0.10),
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
              vertical: AppDimensions.spacing12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20.r, color: accent),
                SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.cardTitle.copyWith(color: accent),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.spacing16,
              AppDimensions.spacing12,
              AppDimensions.spacing16,
              AppDimensions.spacing12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) SizedBox(height: AppDimensions.spacing12),
                  _Step(number: i + 1, text: steps[i], accent: accent),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.text,
    required this.accent,
  });

  final int number;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24.r,
          height: 24.r,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: AppTypography.tiny.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: AppDimensions.spacing12),
        Expanded(
          child: Text(
            text,
            // No maxLines: an instruction that is cut off is worse than one that
            // takes three lines, and these legitimately run long once translated.
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
