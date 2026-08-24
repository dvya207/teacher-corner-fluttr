import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_app_bar.dart';
import '../../core/widgets/tc_section_label.dart';
import 'widgets/guide_card.dart';

/// One topic: a heading, an icon, an accent and its ordered steps.
///
/// Declared as DATA rather than as widgets so the page is a list to scroll and
/// reorder rather than a wall of nested builders, and so the whole guide's
/// structure is readable in one screenful of source.
class _Topic {
  const _Topic({
    required this.icon,
    required this.titleKey,
    required this.stepKeys,
    required this.accent,
  });

  final IconData icon;
  final String titleKey;
  final List<String> stepKeys;
  final Color accent;
}

/// A labelled group of topics.
class _Section {
  const _Section({required this.labelKey, required this.topics});

  final String labelKey;
  final List<_Topic> topics;
}

/// Help & Guide.
///
/// The accents come from the app's own palette and group the topics by kind:
/// blue for finding your way around, navy for the things you do, green for the
/// things you read back, mustard for reference. That grouping is the reason the
/// colour is per-topic rather than uniform.
///
/// TWO THINGS TO KNOW ABOUT THIS CONTENT.
///
/// It is the guide for the FULL Teacher Corner app, reproduced as supplied. Parts
/// of it describe screens this build does not have — a STUDENTS section on a
/// classroom, submitting on a student's behalf, the WhatsApp reminder, Connect
/// with PE, access codes — so a teacher can read a step here and not find the
/// control. That was a deliberate instruction, not an oversight, and it is
/// flagged here so nobody later reads it as one.
///
/// The step text is ENGLISH IN EVERY LOCALE. The keys exist in all ten files, so
/// the picker is honest and a translator has one place to work, but the prose is
/// not translated: machine-translating forty instructional sentences into nine
/// languages would have produced something that reads as broken to a teacher and
/// looked finished to everyone else.
class HelpGuideScreen extends StatelessWidget {
  const HelpGuideScreen({super.key});

  static const List<_Section> _sections = [
    _Section(
      labelKey: 'guide.section_getting_started',
      topics: [
        _Topic(
          icon: Icons.home_outlined,
          titleKey: 'guide.dashboard_title',
          stepKeys: [
            'guide.dashboard_1',
            'guide.dashboard_2',
            'guide.dashboard_3',
          ],
          accent: AppColors.skyBlue,
        ),
        _Topic(
          icon: Icons.menu_book_outlined,
          titleKey: 'guide.classrooms_title',
          stepKeys: [
            'guide.classrooms_1',
            'guide.classrooms_2',
            'guide.classrooms_3',
            'guide.classrooms_4',
          ],
          accent: AppColors.skyBlue,
        ),
      ],
    ),
    _Section(
      labelKey: 'guide.section_submissions',
      topics: [
        _Topic(
          icon: Icons.edit_note_outlined,
          titleKey: 'guide.submit_title',
          stepKeys: [
            'guide.submit_1',
            'guide.submit_2',
            'guide.submit_3',
            'guide.submit_4',
            'guide.submit_5',
            'guide.submit_6',
            'guide.submit_7',
            'guide.submit_8',
          ],
          accent: AppColors.navy,
        ),
        _Topic(
          icon: Icons.visibility_outlined,
          titleKey: 'guide.review_title',
          stepKeys: [
            'guide.review_1',
            'guide.review_2',
            'guide.review_3',
            'guide.review_4',
            'guide.review_5',
            'guide.review_6',
          ],
          accent: AppColors.success,
        ),
        _Topic(
          icon: Icons.book_outlined,
          titleKey: 'guide.lu_title',
          stepKeys: [
            'guide.lu_1',
            'guide.lu_2',
            'guide.lu_3',
            'guide.lu_4',
          ],
          accent: AppColors.ispfMustard,
        ),
      ],
    ),
    _Section(
      labelKey: 'guide.section_profile',
      topics: [
        _Topic(
          icon: Icons.person_outline,
          titleKey: 'guide.profile_title',
          stepKeys: [
            'guide.profile_1',
            'guide.profile_2',
            'guide.profile_3',
            'guide.profile_4',
            'guide.profile_5',
            'guide.profile_6',
          ],
          accent: AppColors.navy,
        ),
      ],
    ),
    _Section(
      labelKey: 'guide.section_whatsapp',
      topics: [
        _Topic(
          icon: Icons.notifications_active_outlined,
          titleKey: 'guide.reminder_title',
          stepKeys: [
            'guide.reminder_1',
            'guide.reminder_2',
            'guide.reminder_3',
            'guide.reminder_4',
            'guide.reminder_5',
          ],
          accent: AppColors.success,
        ),
        _Topic(
          icon: Icons.headset_mic_outlined,
          titleKey: 'guide.pe_title',
          stepKeys: [
            'guide.pe_1',
            'guide.pe_2',
            'guide.pe_3',
            'guide.pe_4',
            'guide.pe_5',
          ],
          accent: AppColors.navy,
        ),
      ],
    ),
    _Section(
      labelKey: 'guide.section_access',
      topics: [
        _Topic(
          icon: Icons.vpn_key_outlined,
          titleKey: 'guide.access_title',
          stepKeys: [
            'guide.access_1',
            'guide.access_2',
            'guide.access_3',
          ],
          accent: AppColors.ispfMustard,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TcAppBar(title: 'profile.help_title'.tr(), showBack: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppDimensions.spacing16,
          AppDimensions.spacing16,
          AppDimensions.spacing16,
          AppDimensions.spacing24,
        ),
        children: [
          for (final section in _sections) ...[
            TcSectionLabel(section.labelKey.tr()),
            SizedBox(height: AppDimensions.spacing12),
            for (final topic in section.topics) ...[
              GuideCard(
                icon: topic.icon,
                title: topic.titleKey.tr(),
                steps: [for (final key in topic.stepKeys) key.tr()],
                accent: topic.accent,
              ),
              SizedBox(height: AppDimensions.spacing12),
            ],
            SizedBox(height: AppDimensions.spacing8),
          ],
          const _NeedMoreHelp(),
        ],
      ),
    );
  }
}

/// The closing card: who to ask when the guide does not answer it.
///
/// Not a [GuideCard]: it has no steps, and forcing it into that shape would mean
/// a numbered list of one.
class _NeedMoreHelp extends StatelessWidget {
  const _NeedMoreHelp();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.headset_mic_outlined, size: 20.r, color: AppColors.navy),
          SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'guide.more_title'.tr(),
                  style: AppTypography.cardTitle.copyWith(
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'guide.more_body'.tr(),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: AppDimensions.spacing8),
                // Rendered as text, not a link: there is no privacy policy URL
                // in this build, and a link that goes nowhere is worse than a
                // line of text. It becomes a link the day there is somewhere for
                // it to go.
                Text(
                  'guide.privacy'.tr(),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.skyBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
