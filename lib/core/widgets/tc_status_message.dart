import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// Semantic class of a status message. Drives colour, icon, and tone across
/// both the inline [TcStatusBanner] and the transient [TcSnack] so the two
/// surfaces never drift apart.
enum TcMsgType { error, success, info }

/// Resolved visual tokens for a [TcMsgType]. Single source of truth so the
/// same semantic always reads the same way wherever it appears.
class _TcMsgTokens {
  final Color accent; // icon + text: a shade of the state colour (never grey)
  final Color background; // low-alpha tint of the accent
  final Color border; // slightly stronger tint for definition
  final IconData icon;
  const _TcMsgTokens(this.accent, this.background, this.border, this.icon);

  factory _TcMsgTokens.of(TcMsgType type) {
    switch (type) {
      case TcMsgType.error:
        return _TcMsgTokens(
          AppColors.error,
          AppColors.error.withValues(alpha: 0.08),
          AppColors.error.withValues(alpha: 0.20),
          Icons.error_outline,
        );
      case TcMsgType.success:
        return _TcMsgTokens(
          AppColors.success,
          AppColors.success.withValues(alpha: 0.10),
          AppColors.success.withValues(alpha: 0.20),
          Icons.check_circle_outline,
        );
      case TcMsgType.info:
        // Navy is the structural voice; a neutral notice is structural, not
        // interactive, so it must NOT use sky (reserved for affordances).
        return _TcMsgTokens(
          AppColors.navy,
          AppColors.navy.withValues(alpha: 0.06),
          AppColors.navy.withValues(alpha: 0.12),
          Icons.info_outline,
        );
    }
  }
}

/// Persistent, in-layout status banner. Use for validation errors, blocking
/// states, and any message the user must be able to re-read. Flat by design:
/// the tint plus a hairline border carry it, no shadow.
class TcStatusBanner extends StatelessWidget {
  final TcMsgType type;
  final String message;

  /// Optional title line above the message (rendered in the accent colour).
  final String? title;

  /// When non-null, a trailing close button is shown. Omit for terminal states
  /// the user cannot dismiss their way out of (e.g. a hard cap block).
  final VoidCallback? onDismiss;

  const TcStatusBanner({
    super.key,
    required this.type,
    required this.message,
    this.title,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final t = _TcMsgTokens.of(type);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing12,
      ),
      decoration: BoxDecoration(
        color: t.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
        border: Border.all(color: t.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(t.icon, size: 20.r, color: t.accent),
          SizedBox(width: AppDimensions.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!,
                      style: AppTypography.label.copyWith(color: t.accent)),
                  SizedBox(height: 2.h),
                ],
                Text(message,
                    style: AppTypography.bodySmall.copyWith(color: t.accent)),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close,
                  size: 18.r, color: t.accent.withValues(alpha: 0.7)),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 40.w, minHeight: 40.h),
              tooltip: 'Dismiss',
            ),
        ],
      ),
    );
  }
}

/// Transient, floating status feedback. Use ONLY for low-stakes, recoverable,
/// non-blocking messages (success toasts, retryable network errors). Never for
/// terminal blocks the user must act on: use [TcStatusBanner] for those.
class TcSnack {
  TcSnack._();

  static void show(
    BuildContext context, {
    required String message,
    TcMsgType type = TcMsgType.info,
  }) {
    final t = _TcMsgTokens.of(type);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar() // never stack toasts
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: AppDimensions.elevationSheet,
          backgroundColor: AppColors.white,
          margin: EdgeInsets.all(AppDimensions.spacing16),
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
            vertical: AppDimensions.spacing12,
          ),
          duration: type == TcMsgType.success
              ? const Duration(seconds: 3)
              : const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            side: BorderSide(color: t.border, width: 1),
          ),
          content: Row(
            children: [
              Icon(t.icon, size: 20.r, color: t.accent),
              SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: Text(message,
                    style: AppTypography.bodySmall.copyWith(color: t.accent)),
              ),
            ],
          ),
        ),
      );
  }
}
