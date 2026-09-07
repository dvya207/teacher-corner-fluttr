import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/locales.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_icon_tile.dart';
import '../../core/widgets/tc_status_message.dart';
import '../auth/auth_provider.dart';

/// Profile, laid out to the approved 2026-08 mockup.
///
/// Three things from that mockup are deliberately absent, on Divya's
/// instruction that "this much is enough" for now:
///
///   - NOTIFICATIONS toggle. Asked for explicitly.
///   - OFFLINE MODE toggle. Not asked for, and not in the list of what to keep.
///     It is also the one control on the page that would have to do something
///     real rather than store a flag, and nothing in this slice implements it,
///     so a switch that only remembers its own position would be a lie.
///   - The eleven language chips are eight short. The mockup shows the
///     production app's full set; this app ships two locale files, so the row is
///     built from `supportedLocales` instead of a hardcoded list. Nine chips
///     that cannot translate anything is a worse outcome than two that can, and
///     dropping another JSON into assets/l10n grows this row on its own.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final account = auth.account;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, auth),
            Padding(
              padding: EdgeInsets.all(AppDimensions.spacing20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (account != null && !account.isLinked) ...[
                    // Signed in, with no `teachers` record carrying this uid. A
                    // real state in teacher-corner-dev, not a failure: it means
                    // nobody has registered this phone number against a
                    // classroom yet.
                    TcStatusBanner(
                      type: TcMsgType.info,
                      message: 'profile.not_linked'.tr(),
                    ),
                    SizedBox(height: AppDimensions.spacing16),
                  ],
                  _statsRow(context, account?.classroomCount ?? 0),
                  SizedBox(height: AppDimensions.spacing16),
                  _languageCard(context),
                  SizedBox(height: AppDimensions.spacing16),
                  _helpCard(context),
                  // NO AUTH UID HERE. There was a debug card printing
                  // `auth.uid` under kDebugMode, because the uid is what
                  // `tools/seed.js --uid=` wants and fetching it from the
                  // Console each time is friction. kDebugMode was the wrong
                  // guard: every build a teacher is handed to try is a debug
                  // build, so it showed a 28-character account identifier on
                  // the profile screen of the app they were reviewing. Read the
                  // uid from the Firebase Console or from a seed script's own
                  // output instead.
                  SizedBox(height: AppDimensions.spacing24),
                  TcButton(
                    label: 'auth.sign_out'.tr(),
                    variant: TcButtonVariant.danger,
                    icon: Icons.logout,
                    isLoading: auth.isBusy,
                    onPressed: auth.signOut,
                  ),
                  SizedBox(height: AppDimensions.spacing24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────── header ──────────────────────────────────

  Widget _header(BuildContext context, AuthProvider auth) {
    final name = auth.account?.displayName ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppDimensions.radiusSheet),
        ),
      ),
      padding: EdgeInsets.only(
        top: AppDimensions.spacing24 + MediaQuery.of(context).padding.top,
        bottom: AppDimensions.spacing24,
        left: AppDimensions.spacing20,
        right: AppDimensions.spacing20,
      ),
      child: Column(
        children: [
          _avatar(name),
          if (name.isNotEmpty) ...[
            SizedBox(height: AppDimensions.spacing12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: AppTypography.heading3.copyWith(color: AppColors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatar(String name) {
    final size = 88.r;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.heroTileBg,
        border: Border.all(color: AppColors.skyBlue, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: AppTypography.heading3.copyWith(color: AppColors.white),
      ),
    );
  }

  /// First letter of the first two words, so "Divya Jain" reads DJ.
  ///
  /// Falls back to a person glyph's stand-in rather than an empty circle when
  /// there is no name yet, which is the state on a database with no teacher
  /// document.
  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  // ───────────────────────────── stats ───────────────────────────────────

  /// The two tiles: how many classrooms this teacher has, and how many
  /// students.
  ///
  /// BOTH ALWAYS RENDER. The classroom count comes from the signed-in teacher's
  /// own account, which [AuthProvider] loads on sign-in, so this screen needs no
  /// load of its own and works whether or not the dashboard has been opened.
  ///
  /// STUDENTS IS A DELIBERATE ZERO PLACEHOLDER, not a computed total, and this
  /// is a change from what this row used to do. It previously read
  /// `DashboardProvider.studentTotal` and OMITTED the tile whenever that was
  /// null — which meant the tile silently vanished for a teacher who opened
  /// Profile without the dashboard having loaded, and made this screen depend on
  /// another tab having been visited first. Two reasons the placeholder is the
  /// right answer for now rather than a fix to that plumbing:
  ///
  ///   - Student enrolment is not modelled in `teacher-corner-dev` at all.
  ///     `studentCounter` is 0 on every classroom document in it, so 0 is the
  ///     true figure today, not a guess standing in for one.
  ///   - The tile is part of the screen's shape. A stat that disappears reads as
  ///     a broken layout, where a zero reads as "none yet".
  ///
  /// The DASHBOARD keeps its stricter behaviour, omitting its own students tile
  /// when a classroom document failed to load, because there it is summing real
  /// per-classroom numbers and a partial sum would understate the total while
  /// looking exact. When enrolment does land, this becomes a real count and the
  /// two screens should agree again.
  Widget _statsRow(BuildContext context, int classroomCount) {
    const int studentsPlaceholder = 0;

    // IntrinsicHeight, because `stretch` inside a scroll view has unbounded
    // height and asserts "BoxConstraints forces an infinite height". This
    // bounds it while still making both cards match the taller one, which is
    // what the mockup shows.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _statCard(
              icon: Icons.home_outlined,
              value: '$classroomCount',
              label: 'dashboard.stat_classrooms'.tr(),
            ),
          ),
          SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: _statCard(
              icon: Icons.person_outline,
              value: '$studentsPlaceholder',
              label: 'dashboard.stat_students'.tr(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return _card(
      // Tighter than the other cards on purpose: two of these share a row.
      padding: AppDimensions.spacing12,
      child: Row(
        children: [
          TcIconTile(icon: icon, size: 34),
          SizedBox(width: AppDimensions.spacing8),
          // Flexible so a three-digit count at the font ceiling wraps rather
          // than overflowing a half-width card.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: AppTypography.sectionTitle.copyWith(
                    color: AppColors.skyBlue,
                  ),
                ),
                Text(label, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────── language ─────────────────────────────────

  Widget _languageCard(BuildContext context) {
    // NOT `context.locale`, which is `EasyLocalization.of(context)!.locale` and
    // null-asserts. The widget test harness loads translations directly without
    // mounting that widget, so the screen would throw in every test while
    // working fine in the app. Ask the provider, fall back to Flutter's own.
    final current =
        EasyLocalization.of(context)?.locale ?? Localizations.localeOf(context);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.language, color: AppColors.textSecondary),
              SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Text(
                  'profile.language'.tr(),
                  style: AppTypography.bodyMedium,
                ),
              ),
              _languageDropdown(context, current),
            ],
          ),
          SizedBox(height: AppDimensions.spacing16),
          // Wrap, not Row: the set grows every time a locale file is added, and
          // it has to fall onto a second line rather than overflow.
          Wrap(
            spacing: AppDimensions.spacing8,
            runSpacing: AppDimensions.spacing8,
            children: [
              for (final locale in kSupportedLocales)
                _localeChip(
                  context,
                  locale,
                  // By language code, not by Locale equality: a resolved locale
                  // can carry a country (en_US) that our list does not.
                  selected: locale.languageCode == current.languageCode,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The current language, as a menu of every language in its OWN script.
  ///
  /// TWO WAYS TO THE SAME ACTION, deliberately. The chips below are fast for
  /// someone who recognises the two-letter code; this menu is for someone who
  /// does not, because it is the only place a teacher sees "ಕನ್ನಡ" rather than
  /// "KN". A teacher who cannot read the current interface language needs to
  /// find their own language by its own name, which a code cannot give them.
  ///
  /// Both read [kSupportedLocales] and both call `setLocale`, so they cannot
  /// disagree about what is on offer or about which is current.
  Widget _languageDropdown(BuildContext context, Locale current) {
    return PopupMenuButton<Locale>(
      // Null-safe on the provider, as everywhere else on this screen: the widget
      // test harness loads translations without mounting EasyLocalization.
      onSelected: (locale) => EasyLocalization.of(context)?.setLocale(locale),
      tooltip: 'profile.language'.tr(),
      position: PopupMenuPosition.under,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      // The whole row is the target, not just the caret: a 12px chevron is not
      // a tap target on a phone held in one hand mid-class.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'language.${current.languageCode}'.tr(),
            style: AppTypography.label.copyWith(color: AppColors.skyBlue),
          ),
          SizedBox(width: 4.w),
          Icon(
            Icons.arrow_drop_down_rounded,
            size: 22.r,
            color: AppColors.skyBlue,
          ),
        ],
      ),
      itemBuilder: (context) => [
        for (final locale in kSupportedLocales)
          PopupMenuItem<Locale>(
            value: locale,
            // Disabled rather than hidden for the current one, so the list is
            // the same length and in the same order every time it opens and the
            // teacher's language does not move under their finger.
            enabled: locale.languageCode != current.languageCode,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'language.${locale.languageCode}'.tr(),
                    // The item is the ONLY place a language name must render in
                    // its own direction regardless of the current locale, so
                    // that Urdu reads correctly from an English interface.
                    // ui.TextDirection, PREFIXED: easy_localization re-exports
                    // intl, whose TextDirection is a class with LTR/RTL
                    // constants rather than dart:ui's enum, so the bare name
                    // resolves to the wrong type here.
                    textDirection: isRtl(locale.languageCode)
                        ? ui.TextDirection.rtl
                        : ui.TextDirection.ltr,
                    style: AppTypography.bodyMedium.copyWith(
                      color: locale.languageCode == current.languageCode
                          ? AppColors.skyBlue
                          : AppColors.textPrimary,
                      fontWeight: locale.languageCode == current.languageCode
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (locale.languageCode == current.languageCode)
                  Icon(Icons.check_rounded,
                      size: 18.r, color: AppColors.skyBlue),
              ],
            ),
          ),
      ],
    );
  }

  Widget _localeChip(
    BuildContext context,
    Locale locale, {
    required bool selected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
      // Null when already selected: re-setting the current locale rebuilds the
      // whole tree for no change.
      // Null-safe on the provider for the same reason as above: no throw in a
      // test that never mounts EasyLocalization.
      onTap: selected
          ? null
          : () => EasyLocalization.of(context)?.setLocale(locale),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing8,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.skyBg : AppColors.bg,
          borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
          border: Border.all(
            color: selected ? AppColors.skyBlue : AppColors.borderLight,
          ),
        ),
        child: Text(
          locale.languageCode.toUpperCase(),
          style: AppTypography.label.copyWith(
            color: selected ? AppColors.skyBlue : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────── help ───────────────────────────────────

  Widget _helpCard(BuildContext context) {
    return _card(
      onTap: () => context.push('/help'),
      child: Row(
        children: [
          const Icon(Icons.help_outline, color: AppColors.skyBlue),
          SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('profile.help_title'.tr(), style: AppTypography.cardTitle),
                Text(
                  'profile.help_subtitle'.tr(),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }

  // ────────────────────────────── shared ─────────────────────────────────

  Widget _card({required Widget child, VoidCallback? onTap, double? padding}) {
    final decorated = Container(
      padding: EdgeInsets.all(padding ?? AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: child,
    );

    if (onTap == null) return decorated;
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      onTap: onTap,
      child: decorated,
    );
  }
}
