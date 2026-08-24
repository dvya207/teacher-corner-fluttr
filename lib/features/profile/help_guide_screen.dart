import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/tc_app_bar.dart';
import '../../core/widgets/tc_empty_state.dart';

/// Help & Guide, deliberately empty until the content arrives.
///
/// It is a real route with a real title rather than a disabled row, because the
/// row exists in the approved design and a control that does nothing reads as a
/// bug. [TcEmptyState] is the same component the app already uses for "there is
/// genuinely nothing here", so this says the true thing in the app's own voice
/// instead of inventing placeholder copy that would have to be deleted later.
///
/// Outside the bottom-nav shell on purpose: the shell picks its active tab from
/// the location, and a route matching no tab would have to be special-cased.
/// A page reached from a row wants a back arrow anyway.
class HelpGuideScreen extends StatelessWidget {
  const HelpGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TcAppBar(title: 'profile.help_title'.tr()),
      body: TcEmptyState(
        icon: Icons.help_outline,
        title: 'profile.help_empty_title'.tr(),
        subtitle: 'profile.help_empty_subtitle'.tr(),
      ),
    );
  }
}
