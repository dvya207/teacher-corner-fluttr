import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/models/resource_kind.dart';
import '../../../core/services/storage_file_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tc_storage_image.dart';
import 'pdf_content_view.dart';
import 'video_content_view.dart';
import 'web_document_view.dart';
import 'youtube_content_view.dart';

/// One resolved resource, shown in the tab rather than handed to the phone.
///
/// THE ONE PLACE THAT MAPS A KIND TO A VIEWER, so the four viewers stay
/// ignorant of each other and of how a kind was decided. Everything upstream
/// of here deals in a [ResolvedResource]; everything downstream deals in a
/// file or a URL it knows how to render.
///
/// WHY THIS REPLACED AN "OPEN" BUTTON. Every one of these used to be a card
/// reading "Opens in another app". The teacher this app is for is standing in
/// front of a class with the phone in one hand: an activity guide that opens
/// in a browser, a video that opens in YouTube and a deck that opens in Drive
/// are three context switches they have to find their way back from, in the
/// ten minutes the step is budgeted for.
class ResourceView extends StatelessWidget {
  const ResourceView({
    super.key,
    required this.resource,
    this.source,
    this.onOpenExternally,
    this.autoPlay = false,
  });

  final ResolvedResource resource;

  /// Injected by tests, which have neither Firebase nor native viewers.
  final StorageFileSource? source;

  /// The fallback, passed to the viewers that can fail in ways a browser
  /// handles. Null in tests, which is also how a viewer knows not to offer it.
  final Future<void> Function()? onOpenExternally;

  /// Passed through to the YouTube viewer for the case where a teacher has
  /// already asked for the video.
  final bool autoPlay;

  @override
  Widget build(BuildContext context) {
    switch (resource.kind) {
      case ResourceKind.youTube:
        return YoutubeContentView(
          // Never null for this kind: the classifier only assigns it once an
          // id has been found and checked.
          videoId: resource.youTubeVideoId!,
          autoPlay: autoPlay,
        );

      case ResourceKind.videoFile:
        return VideoContentView(
          path: resource.value,
          isUrl: resource.isUrl,
          source: source,
        );

      case ResourceKind.pdf:
        return PdfContentView(
          path: resource.value,
          isUrl: resource.isUrl,
          source: source,
          onOpenExternally: onOpenExternally,
        );

      case ResourceKind.image:
        return _Image(resource: resource, source: source);

      case ResourceKind.document:
      case ResourceKind.googleDrive:
        return WebDocumentView(
          path: resource.value,
          isUrl: resource.isUrl,
          source: source,
          onOpenExternally: onOpenExternally,
        );

      case ResourceKind.webPage:
        return _OutwardCard(
          icon: Icons.link_rounded,
          message: 'lu.opens_in_browser',
          onOpen: onOpenExternally,
        );

      case ResourceKind.unrenderable:
        // NAMED, NOT SPUN ON. The value is a reference to another document
        // rather than a file (`graphics.label18Sticker` holds one in live
        // data), so there is nothing to fetch and no viewer that would help.
        return _OutwardCard(
          icon: Icons.help_outline_rounded,
          message: 'lu.content_not_a_file',
          onOpen: null,
        );
    }
  }
}

/// A picture, from Storage or from a URL.
///
/// SPLIT ON WHICH IT IS, because the Storage widget is the one that gets the
/// cache-key-on-path treatment and it has nothing to do for an address that is
/// already an address.
class _Image extends StatelessWidget {
  const _Image({required this.resource, required this.source});

  final ResolvedResource resource;
  final StorageFileSource? source;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.radiusCard);

    if (!resource.isUrl) {
      return TcStorageImage(
        storagePath: resource.value,
        height: 220.h,
        fit: BoxFit.contain,
        source: source,
        borderRadius: radius,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: resource.value,
        height: 220.h,
        fit: BoxFit.contain,
        placeholder: (_, _) => SizedBox(
          height: 220.h,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, _, _) => SizedBox(
          height: 220.h,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 32.r,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row that says what this is and, where there is one, the way out to the
/// system.
///
/// THE ONLY SURVIVING "OPEN" CARD, and deliberately plain. It is now the
/// exception rather than every content's fate, so it does not need the icon
/// vocabulary the old one carried to distinguish a video from a document.
class _OutwardCard extends StatelessWidget {
  const _OutwardCard({
    required this.icon,
    required this.message,
    required this.onOpen,
  });

  final IconData icon;
  final String message;
  final Future<void> Function()? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 26.r, color: AppColors.skyBlue),
              SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Text(message.tr(), style: AppTypography.bodyMedium),
              ),
            ],
          ),
          if (onOpen != null) ...[
            SizedBox(height: AppDimensions.spacing16),
            FilledButton.icon(
              onPressed: () => onOpen!(),
              icon: Icon(Icons.open_in_new_rounded, size: 18.r),
              label: Text('lu.open'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}
