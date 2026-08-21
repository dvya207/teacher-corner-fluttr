import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/tc_app_bar.dart';
import '../../core/widgets/tc_empty_state.dart';

/// A tab that exists in the full Teacher Corner app but is outside the slice
/// being rebuilt here.
///
/// Deliberately explicit rather than a blank screen or a hidden tab: the bottom
/// nav is part of the app's shape, and a teacher tapping Reports deserves to be
/// told it is not here rather than left looking at nothing.
class NotBuiltScreen extends StatelessWidget {
  const NotBuiltScreen({super.key, required this.titleKey, required this.icon});

  /// Localisation key for the tab's own name.
  final String titleKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TcAppBar(title: titleKey.tr()),
      body: TcEmptyState(
        icon: icon,
        title: 'common.not_built_title'.tr(),
        subtitle: 'common.not_built_subtitle'.tr(),
      ),
    );
  }
}
