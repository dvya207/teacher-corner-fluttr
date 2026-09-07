import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_hero_header.dart';
import '../../core/widgets/tc_icon_tile.dart';

/// The Reports tab's landing screen: the report scopes, one card each.
///
/// FOUR CARDS, ONE OF THEM LIVE. The reference app's hub lists the same four
/// and gates them on the teacher's access level; this slice has built
/// Submissions and nothing else. The other three are listed rather than hidden
/// because the hub is the map of what the tab will hold, and a tab that grows
/// a card at a time reads as broken rather than as unfinished. They say so on
/// the row and open the same "not built yet" screen the tab used to be.
class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <_HubEntry>[
      _HubEntry(
        icon: Icons.folder_shared_outlined,
        colour: AppColors.navy,
        titleKey: 'reports.submissions_title',
        subtitleKey: 'reports.submissions_subtitle',
        route: '/reports/submissions',
      ),
      _HubEntry(
        icon: Icons.bar_chart_rounded,
        colour: AppColors.skyBlue,
        titleKey: 'reports.classroom_title',
        subtitleKey: 'reports.classroom_subtitle',
        route: null,
      ),
      _HubEntry(
        icon: Icons.stacked_line_chart_rounded,
        colour: AppColors.ispfTeal,
        titleKey: 'reports.programme_title',
        subtitleKey: 'reports.programme_subtitle',
        route: null,
      ),
      _HubEntry(
        icon: Icons.public_rounded,
        colour: AppColors.ispfMustard,
        titleKey: 'reports.impact_title',
        subtitleKey: 'reports.impact_subtitle',
        route: null,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          TcHeroHeader(
            title: 'reports.title'.tr(),
            subtitle: 'reports.subtitle'.tr(),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(AppDimensions.spacing16),
              itemCount: entries.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: AppDimensions.spacing12),
              itemBuilder: (context, i) => _HubCard(entry: entries[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubEntry {
  const _HubEntry({
    required this.icon,
    required this.colour,
    required this.titleKey,
    required this.subtitleKey,
    required this.route,
  });

  final IconData icon;
  final Color colour;
  final String titleKey;
  final String subtitleKey;

  /// Null for a report that is not built. The card still renders; it just says
  /// so instead of navigating.
  final String? route;
}

class _HubCard extends StatelessWidget {
  const _HubCard({required this.entry});

  final _HubEntry entry;

  @override
  Widget build(BuildContext context) {
    final built = entry.route != null;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: InkWell(
        onTap: built ? () => context.push(entry.route!) : null,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Container(
          padding: EdgeInsets.all(AppDimensions.spacing16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              TcIconTile(
                icon: entry.icon,
                // Muted for a report that does not open yet, so the eye lands
                // on the one that does.
                color: built ? entry.colour : AppColors.textTertiary,
              ),
              SizedBox(width: AppDimensions.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.titleKey.tr(),
                      style: AppTypography.cardTitle.copyWith(
                        color: built
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      built
                          ? entry.subtitleKey.tr()
                          : 'reports.not_built_yet'.tr(),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              if (built)
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                  size: 22.r,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
