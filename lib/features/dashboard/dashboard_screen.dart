import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_brand_tile.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_hero_header.dart';
import '../../core/widgets/tc_hero_stat_tile.dart';
import '../../core/widgets/tc_empty_state.dart';
import '../../core/widgets/tc_loading.dart';
import '../../core/widgets/tc_section_label.dart';
import '../../core/widgets/tc_status_message.dart';
import '../auth/auth_provider.dart';
import '../classrooms/classroom_list_item.dart';
import '../classrooms/widgets/classroom_card.dart';
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
    final account = dashboard.account;
    final name = account?.displayName ?? '';

    return SingleChildScrollView(
      // Scrollable so landscape and a maxed-out system font size push content
      // down rather than overflowing it.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TcHeroHeader(
            // The ThinkTac mark, top left. Only on the dashboard: the classroom
            // and programme screens use that corner for the back arrow, and a
            // logo on every screen is chrome rather than branding.
            leading: const TcBrandMark(),
            overline: 'dashboard.greeting'.tr(),
            // Falls back to the greeting alone rather than rendering an empty
            // title or the word "null".
            title: name.isNotEmpty ? name : 'app.title'.tr(),
            // NO SUBTITLE, deliberately. The institution used to sit under the
            // name here and was removed on instruction: the greeting is about
            // who the teacher is, and their school is already on every classroom
            // card below, so repeating it in the header was noise. The header
            // still resolves it for other screens, which do want it.

            children: [
              // Omitted when the total is not knowable, which happens when an
              // authoritative classroom document did not load. A partial sum
              // would understate the real figure while looking exact.
              if (dashboard.studentTotal != null)
                TcHeroStatTile(
                  value: '${dashboard.studentTotal}',
                  label: 'dashboard.stat_students'.tr(),
                ),
              TcHeroStatTile(
                value: '${account?.classroomCount ?? 0}',
                label: 'dashboard.stat_classrooms'.tr(),
              ),
              TcHeroStatTile(
                value: '${account?.programmeCount ?? 0}',
                label: 'dashboard.stat_programmes'.tr(),
              ),
            ],
          ),
          TcHeroSheet(
            child: dashboard.isTeacherNotLinked
                ? TcStatusBanner(
                    type: TcMsgType.info,
                    message: 'dashboard.not_linked'.tr(),
                  )
                : _ClassroomShortcuts(classrooms: dashboard.classrooms),
          ),
        ],
      ),
    );
  }
}

/// The teacher's classrooms, straight from the document the dashboard already
/// loaded.
///
/// No extra reads: the denormalised `classrooms` map on the teacher is exactly
/// what the counts above are computed from. It carries no `studentCounter`,
/// which is why these rows are built with `full: null` and the card omits that
/// line rather than inventing a zero.
class _ClassroomShortcuts extends StatelessWidget {
  const _ClassroomShortcuts({required this.classrooms});

  final List<ClassroomListItem> classrooms;

  /// A dashboard is a place to start from, not a list to browse. Past a few
  /// rows the searchable Classrooms tab is the better tool, so the rest live
  /// behind "See all".
  static const int _maxRows = 3;

  @override
  Widget build(BuildContext context) {
    if (classrooms.isEmpty) {
      return TcEmptyState(
        icon: Icons.class_outlined,
        title: 'classrooms.empty_title'.tr(),
        subtitle: 'classrooms.empty_subtitle'.tr(),
      );
    }

    final shown = classrooms.take(_maxRows).toList();
    final hasMore = classrooms.length > _maxRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TcSectionLabel(
          'dashboard.your_classrooms'.tr(),
          trailing: hasMore
              ? GestureDetector(
                  onTap: () => context.go('/classrooms'),
                  child: Text(
                    'dashboard.see_all'.tr(),
                    style: AppTypography.label
                        .copyWith(color: AppColors.skyBlue),
                  ),
                )
              : null,
        ),
        SizedBox(height: AppDimensions.spacing8),
        for (final classroom in shown) ...[
          ClassroomCard(
            // Reuses the list's own card, so a classroom looks the same
            // wherever a teacher meets it.
            classroom: classroom,
            // `go`, not `push`: this lands inside the Classrooms branch of the
            // shell, so the bottom nav follows the teacher there.
            onTap: () => context.go('/classrooms/${classroom.classroomId}'),
          ),
          SizedBox(height: AppDimensions.spacing12),
        ],
      ],
    );
  }
}
