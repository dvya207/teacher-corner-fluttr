import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_avatar_chip.dart';
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
import '../classrooms/school_list_item.dart';
import 'dashboard_provider.dart';
import 'greeting.dart';
import 'widgets/dashboard_classroom_row.dart';
import 'widgets/school_card.dart';

/// The teacher's name, their institution, and how much they are carrying.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.now});

  /// The moment the greeting is chosen for. Defaults to the real clock.
  ///
  /// INJECTED SO THE SCREEN IS PHOTOGRAPHABLE. `greetingKeyFor` was already a
  /// pure function and already unit-tested at its boundaries, but the screen
  /// still called `DateTime.now()` itself, which made three golden files
  /// depend on the hour the machine that generated them happened to be in.
  /// They passed all afternoon and failed from five o'clock, and the diff
  /// blamed the greeting rather than whatever change was actually being
  /// reviewed. A golden that expires is worse than no golden: it teaches
  /// whoever hits it to regenerate without looking.
  ///
  /// Production passes nothing and reads the real clock, so this costs the app
  /// nothing and buys the suite determinism.
  final DateTime? now;

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
      final auth = context.read<AuthProvider>();
      final uid = auth.uid;
      if (uid != null) {
        context.read<DashboardProvider>().load(
              uid,
              phoneNumber: auth.phoneNumber,
            );
      }
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
        DashboardStatus.loaded => _LoadedState(
          dashboard: dashboard,
          now: widget.now ?? DateTime.now(),
        ),
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
  const _LoadedState({required this.dashboard, required this.now});

  final DashboardProvider dashboard;

  /// Already resolved by the caller, so this widget never reads a clock and
  /// two rebuilds a millisecond apart cannot disagree about the greeting.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final account = dashboard.account;
    final firstName = account?.firstName ?? '';

    return SingleChildScrollView(
      // Scrollable so landscape and a maxed-out system font size push content
      // down rather than overflowing it.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TcHeroHeader(
            // The ThinkTac mark, top left, at the size the design shows. Only on
            // the dashboard: the classroom and programme screens use that corner
            // for the back arrow, and a logo on every screen is chrome rather
            // than branding.
            leading: const TcBrandMark(size: 64),
            // The avatar sits on its own row at the top right, ABOVE the
            // greeting, and is the short route to the profile from the screen a
            // teacher lands on.
            topTrailing: TcAvatarChip(
              initials: account?.initials ?? '',
              semanticLabel: 'dashboard.open_profile'.tr(),
              onTap: () => context.go('/profile'),
            ),
            // ONE LINE, greeting and name together, because that is what the
            // design shows and because "Good afternoon, Divya" is a sentence
            // where an overline plus a name is a form field. Time of day comes
            // from a pure function so its boundaries are testable.
            //
            // With no name known the greeting still reads correctly: the
            // placeholder takes the app's own name rather than rendering an
            // empty gap or the word "null".
            title: greetingKeyFor(now).tr(
              args: [firstName.isNotEmpty ? firstName : 'app.title'.tr()],
            ),
            // The institution, RIGHT-ALIGNED under the avatar. It was removed
            // from under the name on instruction and belongs here instead: this
            // says which school the numbers below are about, without competing
            // with the greeting.
            subtitle: account?.institutionName,
            subtitleAlignEnd: true,
            // 20, not the shared 24: at 24 the greeting wraps to two lines
            // beside a 64px logo, and the design shows it on one.
            titleFontSize: 20,

            // THREE TILES, ALWAYS, in this order. The row is a fixed shape a
            // teacher learns the positions of, so a tile that comes and goes
            // moves the other two and makes the whole row unreadable at a
            // glance. Anything not knowable says so in its own slot instead.
            //
            // TOTALS ACROSS EVERY SCHOOL, not just the one named above them.
            // The hero answers "how much am I carrying", which is a question
            // about the teacher rather than about a building, and a teacher at
            // four schools carries all four. The per-school breakdown is the
            // "My Schools" section further down, which is where a number
            // attached to one name belongs.
            children: [
              TcHeroStatTile(
                value: '${account?.classroomCount ?? 0}',
                label: 'dashboard.stat_classes'.tr(),
              ),
              TcHeroStatTile(
                // A dash, not a zero, when an authoritative classroom document
                // did not load. A partial sum would understate the real figure
                // while looking exact, and zero is a claim about the teacher's
                // classes rather than about our read. Zero itself is still
                // shown where it is a fact, which is the common case in this
                // data: most classrooms carry no students yet.
                value: dashboard.studentTotal?.toString() ?? '–',
                label: 'dashboard.stat_students'.tr(),
              ),
              TcHeroStatTile(
                // The PROVIDER's count, not the account's: it is computed from
                // the authoritative classroom documents rather than the
                // teacher's denormalised copy, which in live data disagrees
                // with them. See DashboardProvider.programmeCount.
                value: '${dashboard.programmeCount}',
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
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ClassroomShortcuts(classrooms: dashboard.classrooms),
                      _SchoolShortcuts(schools: dashboard.schools),
                    ],
                  ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TcSectionLabel(
          'dashboard.my_classrooms'.tr(),
          // ALWAYS PRESENT, not only when rows are hidden. It used to appear
          // once a fourth classroom existed, which made the header of this
          // section change shape depending on data the teacher cannot see the
          // count of. It is also the twin of the one on "My Schools", and one
          // section having the affordance while the other does not reads as a
          // bug rather than as a rule.
          trailing: _SeeAll(onTap: () => context.go('/classrooms')),
        ),
        SizedBox(height: AppDimensions.spacing8),
        for (final classroom in shown) ...[
          DashboardClassroomRow(
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

/// The schools behind the classrooms above, each with its share of them.
///
/// DERIVED FROM THE SAME ROWS, not read separately. See [SchoolListItem]. So
/// this section costs no extra network and cannot be in a different load state
/// from the classrooms it summarises.
class _SchoolShortcuts extends StatelessWidget {
  const _SchoolShortcuts({required this.schools});

  final List<SchoolListItem> schools;

  @override
  Widget build(BuildContext context) {
    // Nothing at all rather than an empty state. A teacher with no classrooms
    // already has the classrooms empty state directly above this, and a second
    // panel saying the same thing about schools is noise. A teacher WITH
    // classrooms that name no school has a data problem this section cannot
    // explain, and an empty box would not help them either.
    if (schools.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: AppDimensions.spacing8),
        TcSectionLabel(
          'dashboard.my_schools'.tr(),
          // Goes to the CLASSROOMS list, same as the section above it. There is
          // no schools screen: a school in this app is a grouping of
          // classrooms rather than a thing with a page of its own, so "see all"
          // here means "see all of these classrooms", and the list it opens can
          // be searched by school.
          trailing: _SeeAll(onTap: () => context.go('/classrooms')),
        ),
        SizedBox(height: AppDimensions.spacing8),
        for (final school in schools) ...[
          SchoolCard(
            school: school,
            // Opens the classroom list with this school already typed into its
            // search, which is the nearest thing to a school page and reuses a
            // filter that already matches on institution. See
            // ClassroomSearch.filter.
            onTap: () => context.go(
              Uri(
                path: '/classrooms',
                queryParameters: {'q': school.name},
              ).toString(),
            ),
          ),
          SizedBox(height: AppDimensions.spacing12),
        ],
      ],
    );
  }
}

/// The "See all" affordance both sections carry, so the two cannot drift apart
/// in wording, colour or hit area.
class _SeeAll extends StatelessWidget {
  const _SeeAll({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // Opaque, so the padding below is part of the tap target rather than a
      // hole in the middle of it.
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing4,
          vertical: AppDimensions.spacing4,
        ),
        child: Text(
          'dashboard.see_all'.tr(),
          style: AppTypography.label.copyWith(color: AppColors.skyBlue),
        ),
      ),
    );
  }
}
