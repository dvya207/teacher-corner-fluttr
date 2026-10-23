import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/models/submission_report.dart';
import '../../../core/services/storage_file_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tc_photo_viewer.dart';
import '../../../core/widgets/tc_storage_image.dart';

/// Opens the record of everything the teacher submitted against one activity.
void showSubmissionDetailSheet(
  BuildContext context, {
  required String activityLabel,
  required List<SubmissionBlock> blocks,
  StorageFileSource? source,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusSheet),
      ),
    ),
    builder: (context) => SubmissionDetailSheet(
      activityLabel: activityLabel,
      blocks: blocks,
      source: source,
    ),
  );
}

/// Every block a teacher submitted for one activity, in workflow order.
///
/// ONE SCROLLING SHEET, NOT A TAB PER KIND. A teacher checking what they
/// recorded is reconstructing a lesson: the readiness form, then the photos of
/// what the children built, then the observation answers, then the quiz. That
/// is a sequence, and tabs would make them hunt for the order they already
/// know.
///
/// EMPTY BLOCKS ARE SHOWN, with a dash for each unanswered question. The
/// reference sheet does the same, and it is the honest rendering: the block
/// exists in the workflow, the teacher reached the step, and they answered
/// nothing. Hiding it would make the record read as complete.
class SubmissionDetailSheet extends StatelessWidget {
  const SubmissionDetailSheet({
    super.key,
    required this.activityLabel,
    required this.blocks,
    this.source,
  });

  final String activityLabel;
  final List<SubmissionBlock> blocks;

  /// Injected by tests, which have no Firebase Storage behind the thumbnails.
  final StorageFileSource? source;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Handle(),
          _Header(activityLabel: activityLabel),
          const Divider(height: 1, color: AppColors.borderSubtle),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: EdgeInsets.all(AppDimensions.spacing16),
              itemCount: blocks.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: AppDimensions.spacing24),
              itemBuilder: (context, i) =>
                  _Block(block: blocks[i], source: source),
            ),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44.w,
        height: 4,
        margin: EdgeInsets.symmetric(vertical: AppDimensions.spacing12),
        decoration: BoxDecoration(
          color: AppColors.borderLight,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.activityLabel});

  final String activityLabel;

  @override
  Widget build(BuildContext context) {
    return Padding
      (padding: EdgeInsets.fromLTRB(
        AppDimensions.spacing16,
        0,
        AppDimensions.spacing16,
        AppDimensions.spacing16,
      ),
      child: Row(
        children: [
          Icon(Icons.badge_outlined, size: 26.r, color: AppColors.skyBlue),
          SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'reports.teacher_you'.tr(),
                  style: AppTypography.heading2,
                ),
                // THE ACTIVITY, NOT THE CLASSROOM. A teacher opens this from a
                // list of activities they are already looking at; what they
                // need confirmed is which one they tapped.
                Text(
                  activityLabel,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One block: its kind as a chip, then whatever it holds.
class _Block extends StatelessWidget {
  const _Block({required this.block, required this.source});

  final SubmissionBlock block;
  final StorageFileSource? source;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _KindChip(kind: block.kind),
            const Spacer(),
            Text(
              'reports.recorded_by_teacher'.tr(),
              style: AppTypography.caption,
            ),
          ],
        ),
        SizedBox(height: AppDimensions.spacing12),
        if (block.title != null && block.title!.trim().isNotEmpty) ...[
          Text(block.title!, style: AppTypography.bodyStrong),
          SizedBox(height: AppDimensions.spacing8),
        ],
        switch (block.kind) {
          SubmissionBlockKind.form => _Answers(answers: block.answers),
          SubmissionBlockKind.upload => _Photos(
            paths: block.photoPaths,
            source: source,
          ),
          SubmissionBlockKind.quiz => _Quiz(outcome: block.quiz),
        },
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind});

  final SubmissionBlockKind kind;

  String get _label => switch (kind) {
    SubmissionBlockKind.form => 'reports.kind_form',
    SubmissionBlockKind.upload => 'reports.kind_upload',
    SubmissionBlockKind.quiz => 'reports.kind_quiz',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing8,
        vertical: 4.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.skyBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
      ),
      child: Text(
        _label.tr().toUpperCase(),
        style: AppTypography.tiny.copyWith(
          color: AppColors.skyBlue,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Answers extends StatelessWidget {
  const _Answers({required this.answers});

  final List<SubmissionAnswer> answers;

  @override
  Widget build(BuildContext context) {
    if (answers.isEmpty) {
      return Text(
        'reports.nothing_recorded'.tr(),
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final answer in answers) ...[
          Text(
            answer.question,
            style: AppTypography.bodyStrong.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            // A DASH, NOT A BLANK LINE. An unanswered question has to look
            // deliberately unanswered, or the sheet reads as a rendering bug.
            answer.isAnswered ? answer.answer : '—',
            style: AppTypography.bodyMedium.copyWith(
              color: answer.isAnswered
                  ? AppColors.textPrimary
                  : AppColors.textTertiary,
            ),
          ),
          SizedBox(height: AppDimensions.spacing12),
        ],
      ],
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.paths, required this.source});

  final List<String> paths;
  final StorageFileSource? source;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return Text(
        'reports.no_photos'.tr(),
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'reports.photo_count'.plural(paths.length),
          style: AppTypography.caption,
        ),
        SizedBox(height: AppDimensions.spacing8),
        Wrap(
          spacing: AppDimensions.spacing12,
          runSpacing: AppDimensions.spacing12,
          children: [
            for (final (i, path) in paths.indexed)
              // TAPPABLE, and the grid is why. A 96dp thumbnail of a
              // classroom bench tells a teacher a photo exists and nothing
              // about whether the apparatus worked, which is the only reason
              // they opened their own record. The whole set is handed to the
              // viewer, not just this one, so they can swipe the lesson's
              // photos rather than closing and reopening each.
              _Thumbnail(
                path: path,
                onOpen: () => showTcPhotoViewer(
                  context,
                  photos: [for (final p in paths) TcPhoto.storage(p)],
                  initialIndex: i,
                  source: source,
                ),
                source: source,
              ),
          ],
        ),
      ],
    );
  }
}

class _Quiz extends StatelessWidget {
  const _Quiz({required this.outcome});

  final QuizOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final quiz = outcome;
    if (quiz == null) {
      return Text(
        'reports.nothing_recorded'.tr(),
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'reports.quiz_score'.tr(args: ['${quiz.score}', '${quiz.maxScore}']),
          style: AppTypography.heading3,
        ),
        SizedBox(height: 2.h),
        Text(
          [
            if (quiz.percentage != null)
              'reports.quiz_percentage'.tr(
                args: [quiz.percentage!.toStringAsFixed(0)],
              ),
            'reports.quiz_attempts'.plural(quiz.attempts),
          ].join(' · '),
          style: AppTypography.caption,
        ),
      ],
    );
  }
}

/// One submitted photo: the image, and the glyph saying it opens.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.path,
    required this.onOpen,
    required this.source,
  });

  final String path;
  final VoidCallback onOpen;
  final StorageFileSource? source;

  @override
  Widget build(BuildContext context) {
    final side = 96.r;
    final radius = BorderRadius.circular(AppDimensions.radiusInput);

    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // STORAGE PATHS, resolved through the shared cache-on-path source.
          // A stored download URL carries a token that expires, which is why
          // the path is what the record keeps.
          TcStorageImage(
            storagePath: path,
            fit: BoxFit.cover,
            source: source,
            borderRadius: radius,
          ),
          Positioned(right: 4.r, bottom: 4.r, child: const TcExpandBadge()),
          // THE TAP TARGET LAST, so it sits above the image and the badge and
          // the whole square is tappable rather than only the glyph.
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpen,
                borderRadius: radius,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
