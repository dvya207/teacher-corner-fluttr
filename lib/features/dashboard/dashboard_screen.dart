import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_hero_header.dart';
import '../../core/widgets/tc_hero_stat_tile.dart';
import '../../core/widgets/tc_loading.dart';
import '../../core/widgets/tc_status_message.dart';
import '../auth/auth_provider.dart';
import 'dashboard_provider.dart';

/// The teacher's name, their institution, and how much they are carrying.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame, not during initState: load() notifies listeners,
    // and notifying while the tree is still building throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().uid;
      if (uid != null) context.read<DashboardProvider>().load(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: switch (dashboard.status) {
        DashboardStatus.loading => TcLoading(message: 'common.loading'.tr()),
        DashboardStatus.error => _ErrorState(
            messageKey: dashboard.errorKey ?? 'dashboard.error_generic',
            onRetry: dashboard.retry,
          ),
        DashboardStatus.loaded => _LoadedState(dashboard: dashboard),
      },
    );
  }
}

/// A real error state: it says what went wrong and offers the one action that
/// might fix it. Not a spinner, and not a blank screen.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.messageKey, required this.onRetry});

  final String messageKey;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TcStatusBanner(
              type: TcMsgType.error,
              title: 'dashboard.error_title'.tr(),
              message: messageKey.tr(),
            ),
            SizedBox(height: AppDimensions.spacing24),
            TcButton(label: 'common.retry'.tr(), onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _LoadedState extends StatelessWidget {
  const _LoadedState({required this.dashboard});

  final DashboardProvider dashboard;

  @override
  Widget build(BuildContext context) {
    final teacher = dashboard.teacher;
    final name = teacher?.displayName ?? '';

    return SingleChildScrollView(
      // Scrollable so landscape and a maxed-out system font size push content
      // down rather than overflowing it.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TcHeroHeader(
            overline: 'dashboard.greeting'.tr(),
            // Falls back to the greeting alone rather than rendering an empty
            // title or the word "null".
            title: name.isNotEmpty ? name : 'app.title'.tr(),
            subtitle: teacher?.institutionName,
            children: [
              TcHeroStatTile(
                value: '${teacher?.classroomCount ?? 0}',
                label: 'dashboard.stat_classrooms'.tr(),
              ),
              TcHeroStatTile(
                value: '${teacher?.programmeCount ?? 0}',
                label: 'dashboard.stat_programmes'.tr(),
              ),
            ],
          ),
          TcHeroSheet(
            child: dashboard.hasNoProfile
                ? TcStatusBanner(
                    type: TcMsgType.info,
                    message: 'dashboard.no_profile'.tr(),
                  )
                : Text(
                    'nav.classrooms'.tr(),
                    style: AppTypography.sectionTitle,
                  ),
          ),
        ],
      ),
    );
  }
}
