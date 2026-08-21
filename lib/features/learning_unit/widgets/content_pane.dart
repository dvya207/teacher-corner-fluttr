import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/models/workflow.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tc_empty_state.dart';
import '../../../core/widgets/tc_storage_image.dart';

/// One tab's worth of content inside a workflow step.
///
/// Keeps itself alive. Combined with the [IndexedStack] its parent uses, that
/// means switching tabs and coming back does not tear the pane down and rebuild
/// it: a destroyed tab is a re-resolved image and a re-downloaded file.
class ContentPane extends StatefulWidget {
  const ContentPane({
    super.key,
    required this.content,
    this.evidenceBuilder,
  });

  final WorkflowContent content;

  /// Supplied for an upload assignment. Left null the pane says so rather than
  /// rendering an empty box.
  final WidgetBuilder? evidenceBuilder;

  @override
  State<ContentPane> createState() => _ContentPaneState();
}

class _ContentPaneState extends State<ContentPane>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // Required by the mixin.
    super.build(context);

    final content = widget.content;

    if (content.isUploadAssignment) {
      final builder = widget.evidenceBuilder;
      if (builder != null) return builder(context);
      return TcEmptyState(
        icon: Icons.photo_camera_outlined,
        title: 'lu.evidence'.tr(),
        subtitle: 'lu.no_content_subtitle'.tr(),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (content.contentName != null &&
              content.contentName!.trim().isNotEmpty) ...[
            Text(content.contentName!, style: AppTypography.sectionTitle),
            SizedBox(height: AppDimensions.spacing12),
          ],
          if (content.isImage && content.hasResource)
            TcStorageImage(
              storagePath: content.resourcePath,
              height: 220.h,
              fit: BoxFit.contain,
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusCard),
            )
          else if (content.isDocument && content.hasResource)
            _DocumentRow(name: content.contentName)
          else
            // No renderable body. SCHEMA.md gives contents a resourcePath but
            // no text field, and every seeded content has an empty path, so
            // this is the honest state rather than a blank pane.
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: AppDimensions.spacing24,
              ),
              child: Text(
                'lu.content_unavailable'.tr(),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined,
              size: 22.r, color: AppColors.skyBlue),
          SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Text(
              name ?? 'lu.document'.tr(),
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
