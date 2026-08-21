import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_app_bar.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_status_message.dart';
import '../auth/auth_provider.dart';

/// Minimal profile: who is signed in, and the way back out.
///
/// Built in Phase 1 rather than left as a placeholder because sign-out is half
/// of the phase's acceptance check, and a route guard you cannot exercise is a
/// route guard you have not tested.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final teacher = auth.teacher;
    final name = teacher?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TcAppBar(title: 'nav.profile'.tr()),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (name.isNotEmpty)
              Text(name, style: AppTypography.heading3)
            else
              // Authenticated but no teacher document. A real state on a fresh
              // database, and not a failure: say so plainly instead of showing
              // an empty header or the word "null".
              TcStatusBanner(
                type: TcMsgType.info,
                message: 'profile.no_profile'.tr(),
              ),
            if (teacher?.institutionName != null) ...[
              SizedBox(height: AppDimensions.spacing4),
              Text(teacher!.institutionName!, style: AppTypography.caption),
            ],
            if (teacher?.meta?.designation != null) ...[
              SizedBox(height: AppDimensions.spacing4),
              Text(teacher!.meta!.designation!, style: AppTypography.caption),
            ],

            // Debug only. The uid is what `tools/seed.js --uid=` needs, and
            // hunting for it in the Console every time is friction. It has no
            // business on a teacher's screen in a release build.
            if (kDebugMode && auth.uid != null) ...[
              SizedBox(height: AppDimensions.spacing24),
              Text('profile.uid_label'.tr(), style: AppTypography.label),
              SizedBox(height: AppDimensions.spacing4),
              SelectableText(auth.uid!, style: AppTypography.bodySmall),
            ],

            SizedBox(height: AppDimensions.spacing32),
            TcButton(
              label: 'auth.sign_out'.tr(),
              variant: TcButtonVariant.outlined,
              isLoading: auth.isBusy,
              onPressed: auth.signOut,
            ),
          ],
        ),
      ),
    );
  }
}
