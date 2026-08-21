import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_status_message.dart';

/// Shown when a pre-`runApp` step failed.
///
/// The point is that it EXISTS: without it the app sits on a blank splash and
/// the teacher has no way to tell a slow start from a dead one.
class StartupFailureScreen extends StatelessWidget {
  const StartupFailureScreen({
    super.key,
    required this.onRetry,
    this.busy = false,
    this.localized = true,
  });

  final Future<void> Function() onRetry;
  final bool busy;

  /// False when localization itself failed to initialise, in which case `.tr()`
  /// would render raw keys. The English fallbacks below are the deliberate last
  /// resort for that one path, and the only user-facing strings in the app not
  /// coming from `assets/l10n`.
  final bool localized;

  String _text(String key, String fallback) => localized ? key.tr() : fallback;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppDimensions.spacing24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _text(
                    'startup.error_title',
                    'Teacher Corner could not start',
                  ),
                  style: AppTypography.heading3,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppDimensions.spacing16),
                TcStatusBanner(
                  type: TcMsgType.error,
                  message: _text(
                    'startup.error_message',
                    'Something went wrong setting up the app on this device. '
                        'Try again, and if it keeps happening, reinstall.',
                  ),
                ),
                SizedBox(height: AppDimensions.spacing24),
                TcButton(
                  label: _text('startup.retry', 'Try again'),
                  isLoading: busy,
                  onPressed: busy ? null : onRetry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
