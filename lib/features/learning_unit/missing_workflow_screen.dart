import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/tc_app_bar.dart';
import '../../core/widgets/tc_empty_state.dart';

/// Shown when `/lu/:id` is opened without a `workflowId`.
///
/// Not an error page for the sake of it. Which workflow a learning unit runs is
/// a property of the classroom, so a link that omits it genuinely cannot be
/// resolved, and picking any workflow would walk the teacher through steps that
/// are not the ones their classroom is doing.
class MissingWorkflowScreen extends StatelessWidget {
  const MissingWorkflowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TcAppBar(title: 'lu.steps'.tr(), showBack: true),
      body: TcEmptyState(
        icon: Icons.link_off_rounded,
        title: 'lu.not_found_title'.tr(),
        subtitle: 'lu.not_found_subtitle'.tr(),
      ),
    );
  }
}
