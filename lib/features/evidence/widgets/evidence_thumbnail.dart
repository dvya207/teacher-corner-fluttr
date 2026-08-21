import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/services/storage_image_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/tc_storage_image.dart';

/// One photo in the review grid, with the affordance to take it back out.
///
/// A local [file] for something chosen but not sent; a [storagePath] for
/// something already submitted. The submitted case goes through
/// [TcStorageImage] rather than rendering the stored download URL, so it shares
/// the same path-keyed cache as every other image in the app.
class EvidenceThumbnail extends StatelessWidget {
  const EvidenceThumbnail({
    super.key,
    this.file,
    this.storagePath,
    this.onRemove,
    this.imageSource,
  }) : assert(file != null || storagePath != null,
            'a thumbnail needs either a local file or a storage path');

  final File? file;
  final String? storagePath;
  final VoidCallback? onRemove;
  final StorageImageSource? imageSource;

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
}
