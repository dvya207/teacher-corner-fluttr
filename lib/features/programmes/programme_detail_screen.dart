import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/models/programme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_chip.dart';
import '../../core/widgets/tc_hero_header.dart';
import '../../core/widgets/tc_loading.dart';
import '../../core/widgets/tc_section_label.dart';
import '../../core/widgets/tc_status_message.dart';
import 'programme_detail_provider.dart';

/// One programme, showing exactly what its catalogue document holds.
///
/// NOTHING HERE IS INVENTED. Every row is a field that exists on every
/// `programmes/{id}` document in `teacher-corner-dev`, and a field that is blank
/// in the data is OMITTED rather than filled with a placeholder or an em dash.
/// The screen is therefore shorter for a thinly-filled programme, which is an
/// honest reflection of the record rather than a gap to pad.
///
/// Learning units and assignments are deliberately absent: `learningUnitsIds` is
/// empty on every document and the collection those ids would point at has no
/// documents, so a section for them would be a permanently empty shell. The
/// counts are surfaced as a single line instead, so the moment they are
/// populated it is visible here.
class ProgrammeDetailScreen extends StatefulWidget {
  const ProgrammeDetailScreen({
    super.key,
    required this.programmeId,
    this.classroomName,
  });

  final String programmeId;

  /// The classroom this was opened from, for the breadcrumb only. Optional
  /// because a programme is reachable by its own route and does not belong to
  /// one classroom — the same programme runs in several.
  final String? classroomName;

  @override
  State<ProgrammeDetailScreen> createState() => _ProgrammeDetailScreenState();
}

class _ProgrammeDetailScreenState extends State<ProgrammeDetailScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame, not during initState: load() notifies listeners,
    // and notifying while the tree is still building throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProgrammeDetailProvider>().load(widget.programmeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<ProgrammeDetailProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: switch (detail.status) {
        ProgrammeDetailStatus.loading =>
          TcLoading(message: 'common.loading'.tr()),
        ProgrammeDetailStatus.error => _ErrorState(
            messageKey: detail.errorKey ?? 'programme.error_generic',
            onRetry: detail.retry,
          ),
        // Referenced by a classroom, absent from the catalogue. Not an error.
        ProgrammeDetailStatus.notFound => const _NotFoundState(),
        ProgrammeDetailStatus.loaded => _Loaded(
            programme: detail.programme!,
            classroomName: widget.classroomName,
          ),
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.programme, this.classroomName});

  final Programme programme;
  final String? classroomName;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TcHeroHeader(
            breadcrumb: classroomName,
            showBack: true,
            onBack: () => Navigator.of(context).maybePop(),
            // The code identifies the programme across the platform, so it
            // earns the overline. Omitted when the document has none.
            overline: programme.programmeCode,
            title: programme.label,
            subtitle: programme.institutionName,
          ),
          TcHeroSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _statusRow(programme),
                if (programme.description != null) ...[
                  SizedBox(height: AppDimensions.spacing20),
                  TcSectionLabel('programme.about'.tr()),
                  SizedBox(height: AppDimensions.spacing8),
                  Text(programme.description!, style: AppTypography.bodyMedium),
                ],
                SizedBox(height: AppDimensions.spacing20),
                TcSectionLabel('programme.details'.tr()),
                SizedBox(height: AppDimensions.spacing8),
                ..._facts(context, programme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The two chips that classify the programme. Both come straight from stored
  /// values rather than being derived, so a status this app has not seen before
  /// still renders as itself.
  Widget _statusRow(Programme programme) {
    return Wrap(
      spacing: AppDimensions.spacing8,
      runSpacing: AppDimensions.spacing8,
      children: [
        if (programme.status != null)
          TcChip(
            label: programme.isLive
                ? 'programme.status_live'.tr()
                : 'programme.status_draft'.tr(),
            color: programme.isLive ? AppColors.ispfTeal : AppColors.textTertiary,
          ),
        if (programme.type != null)
          TcChip(
            label: programme.isStemClub
                ? 'programme.type_stem_club'.tr()
                : 'programme.type_regular'.tr(),
            color: AppColors.navy,
          ),
      ],
    );
  }

  /// One row per fact the document actually carries. A blank field produces no
  /// row at all.
  List<Widget> _facts(BuildContext context, Programme programme) {
    final rows = <(String, String)>[
      if (programme.gradeRange != null)
        ('programme.grades', programme.gradeRange!),
      if (programme.ageRange != null) ('programme.ages', programme.ageRange!),
      if (programme.institutionName != null)
        ('programme.institution', programme.institutionName!),
      // programmeName is shown only when it differs from what the title
      // already says, so the row carries information instead of repeating it.
      if (programme.programmeName != null &&
          programme.programmeName!.trim() != programme.label)
        ('programme.catalogue_name', programme.programmeName!),
      (
        'programme.learning_units',
        '${programme.learningUnitIds.length}',
      ),
      if (programme.assignmentIds.isNotEmpty)
        ('programme.assignments', '${programme.assignmentIds.length}'),
      if (programme.updatedAt != null)
        ('programme.updated', _date(programme.updatedAt!)),
    ];

    return [
      for (final (key, value) in rows) ...[
        _factRow(key.tr(), value),
        SizedBox(height: AppDimensions.spacing8),
      ],
      if (programme.learningUnitIds.isEmpty)
        TcStatusBanner(
          type: TcMsgType.info,
          message: 'programme.no_learning_units'.tr(),
        ),
    ];
  }

  Widget _factRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132.w,
          child: Text(label, style: AppTypography.caption),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall,
          ),
        ),
      ],
    );
  }

  /// Date only, no time. A programme's timestamps are bookkeeping; the hour it
  /// was edited is noise to a teacher.
  String _date(DateTime value) =>
      DateFormat.yMMMd().format(value.toLocal());
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TcStatusBanner(
              type: TcMsgType.info,
              title: 'programme.not_found_title'.tr(),
              message: 'programme.not_found_subtitle'.tr(),
            ),
            SizedBox(height: AppDimensions.spacing24),
            TcButton(
              label: 'common.back'.tr(),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

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
              title: 'programme.error_title'.tr(),
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
