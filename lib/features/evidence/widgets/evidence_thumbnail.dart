import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/services/storage_file_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/tc_photo_viewer.dart';
import '../../../core/widgets/tc_storage_image.dart';

/// One photo in the review grid: tappable to see it properly, with the
/// affordance to take it back out.
///
/// A local [file] for something chosen but not sent; a [storagePath] for
/// something already submitted. The submitted case goes through
/// [TcStorageImage] rather than rendering the stored download URL, so it shares
/// the same path-keyed cache as every other image in the app.
///
/// TAPPING OPENS IT FULL SCREEN. A 92dp square is enough to confirm a photo
/// exists and not enough to check the thing it was taken to record: whether
/// the apparatus in front of the children actually worked. That is the whole
/// point of photographing it, so the thumbnail is a way in rather than the
/// only view.
class EvidenceThumbnail extends StatelessWidget {
  const EvidenceThumbnail({
    super.key,
    this.file,
    this.storagePath,
    this.onRemove,
    this.onOpen,
    this.imageSource,
  }) : assert(file != null || storagePath != null,
            'a thumbnail needs either a local file or a storage path');

  final File? file;
  final String? storagePath;
  final VoidCallback? onRemove;

  /// Opens the photo full screen. Null falls back to opening just this one,
  /// which is what a single thumbnail on its own should do; the panel passes a
  /// callback so a swipe moves through the whole set.
  final VoidCallback? onOpen;

  final StorageFileSource? imageSource;

  @override
  Widget build(BuildContext context) {
    final side = 92.r;
    final radius = BorderRadius.circular(AppDimensions.radiusInput);

    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (file != null)
            ClipRRect(
              borderRadius: radius,
              child: Image.file(
                file!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: AppColors.borderSubtle,
                  child: Icon(Icons.broken_image_outlined,
                      size: 20.r, color: AppColors.textDisabled),
                ),
              ),
            )
          else
            TcStorageImage(
              storagePath: storagePath,
              borderRadius: radius,
              source: imageSource,
            ),
          // BELOW THE REMOVE BUTTON IN THE STACK, so the small X still wins
          // its own corner. A teacher deleting the wrong photo because the
          // viewer swallowed the tap is the worse failure of the two.
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _open(context),
                borderRadius: radius,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(right: 4.r, bottom: 4.r, child: const TcExpandBadge()),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: AppColors.textPrimary.withValues(alpha: 0.65),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: Tooltip(
                    message: 'evidence.remove'.tr(),
                    child: Padding(
                      padding: EdgeInsets.all(4.r),
                      child: Icon(Icons.close,
                          size: 16.r, color: AppColors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _open(BuildContext context) {
    final handler = onOpen;
    if (handler != null) {
      handler();
      return;
    }
    showTcPhotoViewer(
      context,
      photos: [
        if (file != null)
          TcPhoto.file(file!)
        else if (storagePath != null)
          TcPhoto.storage(storagePath!),
      ],
      source: imageSource,
    );
  }
}
