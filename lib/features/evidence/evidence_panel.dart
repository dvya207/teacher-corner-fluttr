import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/services/photo_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_empty_state.dart';
import '../../core/widgets/tc_gradient_button.dart';
import '../../core/widgets/tc_loading.dart';
import '../../core/widgets/tc_photo_viewer.dart';
import '../../core/widgets/tc_section_label.dart';
import '../../core/widgets/tc_status_message.dart';
import 'evidence_provider.dart';
import 'widgets/evidence_thumbnail.dart';

/// Everything needed to address one assignment's evidence document.
class EvidenceTarget {
  const EvidenceTarget({
    required this.classroomId,
    required this.programmeId,
    required this.learningUnitId,
    required this.assignmentId,
    this.displayName,
  });

  final String classroomId;
  final String programmeId;
  final String learningUnitId;
  final String assignmentId;
  final String? displayName;
}

/// Lets the learning unit screen supply the evidence pane, so a test can render
/// the step without Storage or a camera behind it.
typedef EvidencePanelBuilder = Widget Function(
  BuildContext context,
  EvidenceTarget target,
);

/// Pick, review, submit.
///
/// The three sections are deliberately distinct: what is chosen but not sent,
/// what has been sent, and the one Submit that moves the first into the second.
class EvidencePanel extends StatefulWidget {
  const EvidencePanel({super.key});

  @override
  State<EvidencePanel> createState() => _EvidencePanelState();
}

class _EvidencePanelState extends State<EvidencePanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EvidenceProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EvidenceProvider>();

    if (provider.status == EvidenceStatus.loading) {
      return TcLoading(message: 'common.loading'.tr());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A HEADER ROW, NOT A STACK OF FOUR TEXTS. This block used to be a
          // title, an intro, the size limit and the count, each on its own
          // line, which put four lines of small grey type above the only two
          // controls that do anything. The count is the fact a teacher checks
          // ("have I done this one?"), so it is what sits beside the title, and
          // the limits move to a single line under the buttons where they are
          // read at the moment they matter.
          Row(
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // Green once anything is in, grey while it is empty, so the
                  // step's state is legible without reading the number.
                  color: provider.isEmpty
                      ? AppColors.borderSubtle
                      : AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusCard,
                  ),
                ),
                child: Icon(
                  provider.isEmpty
                      ? Icons.photo_camera_outlined
                      : Icons.check_circle_rounded,
                  size: 24.r,
                  color: provider.isEmpty
                      ? AppColors.textTertiary
                      : AppColors.success,
                ),
              ),
              SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'evidence.title'.tr(),
                      style: AppTypography.heading3,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'evidence.submitted_of'.tr(
                        args: [
                          '${provider.submitted.length}',
                          '$kMaxEvidencePhotos',
                        ],
                      ),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (provider.errorKey != null) ...[
            SizedBox(height: AppDimensions.spacing12),
            TcStatusBanner(
              type: TcMsgType.error,
              message: provider.errorKey!.tr(args: provider.errorArgs),
              onDismiss: provider.clearError,
            ),
          ],

          SizedBox(height: AppDimensions.spacing16),
          Text('evidence.intro'.tr(), style: AppTypography.caption),
          SizedBox(height: AppDimensions.spacing12),
          // Both sources, always. A teacher may be photographing the desk in
          // front of them or adding a shot from earlier in the lesson.
          Row(
            children: [
              Expanded(
                child: TcButton(
                  label: 'evidence.from_camera'.tr(),
                  icon: Icons.photo_camera_outlined,
                  variant: TcButtonVariant.outlined,
                  onPressed: provider.remainingSlots <= 0 || provider.isBusy
                      ? null
                      : () => provider.pick(PhotoSource.camera),
                ),
              ),
              SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: TcButton(
                  label: 'evidence.from_gallery'.tr(),
                  icon: Icons.photo_library_outlined,
                  variant: TcButtonVariant.outlined,
                  onPressed: provider.remainingSlots <= 0 || provider.isBusy
                      ? null
                      : () => provider.pick(PhotoSource.gallery),
                ),
              ),
            ],
          ),

          SizedBox(height: AppDimensions.spacing8),
          // ONE LINE, UNDER THE BUTTONS, and stated before a refusal rather
          // than after one. Format, size and count together: all three are
          // reasons a pick can be rejected, and a teacher who has just been
          // refused should not have to hunt for which one they hit.
          Text(
            'evidence.format_limits'.tr(args: [
              '${kMaxEvidenceBytes ~/ 1048576}',
              '$kMaxEvidencePhotos',
            ]),
            style: AppTypography.tiny,
            textAlign: TextAlign.center,
          ),

          if (provider.isEmpty) ...[
            SizedBox(height: AppDimensions.spacing24),
            TcEmptyState(
              icon: Icons.photo_camera_outlined,
              title: 'evidence.empty_title'.tr(),
              subtitle: 'evidence.empty_subtitle'.tr(),
            ),
          ],

          if (provider.pending.isNotEmpty) ...[
            SizedBox(height: AppDimensions.spacing16),
            TcSectionLabel('evidence.ready_title'.tr()),
            Text('evidence.not_uploaded_yet'.tr(),
                style: AppTypography.tiny),
            SizedBox(height: AppDimensions.spacing8),
            _Thumbnails(
              children: [
                for (var i = 0; i < provider.pending.length; i++)
                  EvidenceThumbnail(
                    file: provider.pending[i].file,
                    // THE WHOLE SET, not just this one. A teacher checking
                    // three photos before submitting should swipe between
                    // them rather than close and reopen each.
                    onOpen: () => showTcPhotoViewer(
                      context,
                      photos: [
                        for (final p in provider.pending) TcPhoto.file(p.file),
                      ],
                      initialIndex: i,
                    ),
                    onRemove:
                        provider.isBusy ? null : () => provider.removePending(i),
                  ),
              ],
            ),
            SizedBox(height: AppDimensions.spacing16),
            TcGradientButton(
              label: provider.pending.length == 1
                  ? 'evidence.submit_one'.tr()
                  : 'evidence.submit'.tr(args: ['${provider.pending.length}']),
              isLoading: provider.isBusy,
              onPressed: provider.canSubmit ? provider.submit : null,
            ),
          ],

          if (provider.submitted.isNotEmpty) ...[
            SizedBox(height: AppDimensions.spacing24),
            TcSectionLabel('evidence.submitted_title'.tr()),
            SizedBox(height: AppDimensions.spacing8),
            _Thumbnails(
              children: [
                for (var i = 0; i < provider.submitted.length; i++)
                  EvidenceThumbnail(
                    storagePath: provider.submitted[i].storagePath,
                    onOpen: () => showTcPhotoViewer(
                      context,
                      photos: [
                        for (final p in provider.submitted)
                          TcPhoto.storage(p.storagePath),
                      ],
                      initialIndex: i,
                    ),
                    onRemove: provider.isBusy
                        ? null
                        : () => provider.removeSubmitted(i),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Thumbnails extends StatelessWidget {
  const _Thumbnails({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.spacing12,
      runSpacing: AppDimensions.spacing12,
      children: children,
    );
  }
}

/// Shown when the screen was reached without the ids the evidence document is
/// addressed by, so there is nothing coherent to write to.
class EvidenceUnavailable extends StatelessWidget {
  const EvidenceUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    return TcEmptyState(
      icon: Icons.link_off_rounded,
      title: 'evidence.title'.tr(),
      subtitle: 'lu.not_found_subtitle'.tr(),
    );
  }
}
