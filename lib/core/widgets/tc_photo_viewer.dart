import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/storage_file_source.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import 'tc_storage_image.dart';

/// One photo to show full screen: either already on disk, or in Storage.
///
/// A PAIR RATHER THAN A URL, and for the reason every image in this app is
/// addressed by path: a download URL carries a token that expires, so the
/// stable identity of a submitted photo is its Storage path. A photo picked but
/// not yet sent has no path at all and is only a local file.
class TcPhoto {
  const TcPhoto.file(File this.file) : storagePath = null;
  const TcPhoto.storage(String this.storagePath) : file = null;

  final File? file;
  final String? storagePath;
}

/// Shows [photos] OVER the current screen, starting at [initialIndex].
///
/// AN OVERLAY, NOT A PAGE, and the difference is what a teacher is doing. They
/// are part-way down their own submission record, or reviewing three photos
/// before pressing Submit, and they want a closer look at one of them without
/// leaving the place they were reading. A pushed page takes the screen away and
/// gives it back scrolled to wherever it was; an overlay leaves the list
/// exactly where they left it, underneath.
///
/// It still dismisses on the system back gesture, because a dialog route does.
/// Tapping outside the photo closes it too, which on a screen that is almost
/// entirely photo means the margins.
Future<void> showTcPhotoViewer(
  BuildContext context, {
  required List<TcPhoto> photos,
  int initialIndex = 0,
  StorageFileSource? source,
}) {
  if (photos.isEmpty) return Future<void>.value();
  return showDialog<void>(
    context: context,
    // Nearly black, so the photograph is judged against black rather than
    // against whichever card it was sitting on.
    barrierColor: Colors.black.withValues(alpha: 0.92),
    barrierLabel: 'common.close'.tr(),
    // FULL BLEED. The default dialog insets would letterbox a portrait photo
    // into a stamp in the middle of the screen, which is the problem this is
    // meant to solve.
    useSafeArea: false,
    builder: (_) => TcPhotoViewer(
      photos: photos,
      initialIndex: initialIndex.clamp(0, photos.length - 1),
      source: source,
    ),
  );
}

/// Full-screen photos, pinch to zoom, swipe between them.
class TcPhotoViewer extends StatefulWidget {
  const TcPhotoViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.source,
  });

  final List<TcPhoto> photos;
  final int initialIndex;

  /// Injected by tests, which have no Firebase Storage behind the paths.
  final StorageFileSource? source;

  @override
  State<TcPhotoViewer> createState() => _TcPhotoViewerState();
}

class _TcPhotoViewerState extends State<TcPhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.photos.length > 1;

    // NO SCAFFOLD AND NO APP BAR. This sits inside a dialog route over the
    // screen the teacher was on, so it paints only the photo and its two
    // controls; the barrier behind it is what darkens everything else.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pages,
              // PageView and InteractiveViewer only conflict once zoomed, and
              // the pan gesture wins inside the zoomed child.
              physics: many
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: widget.photos.length,
              itemBuilder: (context, i) => _Page(
                photo: widget.photos[i],
                source: widget.source,
              ),
            ),
          ),
          // The counter and the way out, floated over the photo rather than
          // given a bar of their own, so the photo keeps the whole screen.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.spacing8),
                child: Row(
                  children: [
                    _RoundButton(
                      icon: Icons.close_rounded,
                      tooltip: 'common.close'.tr(),
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    if (many)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacing12,
                          vertical: AppDimensions.spacing4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusChip,
                          ),
                        ),
                        child: Text(
                          'evidence.photo_of'.tr(
                            args: [
                              '${_index + 1}',
                              '${widget.photos.length}',
                            ],
                          ),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dark circular target, legible over a photograph of any brightness.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            // 48dp overall, the minimum tactile target, whatever the glyph
            // scales to.
            padding: EdgeInsets.all(12.r),
            child: Icon(icon, size: 24.r, color: AppColors.white),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.photo, required this.source});

  final TcPhoto photo;
  final StorageFileSource? source;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      // A teacher zooming into a corner of a photograph should be able to keep
      // going past the edge; clamping to the box makes the far corner
      // unreachable at high zoom.
      boundaryMargin: EdgeInsets.all(AppDimensions.spacing24),
      child: Center(
        child: photo.file != null
            ? Image.file(
                photo.file!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const _Unavailable(),
              )
            : TcStorageImage(
                storagePath: photo.storagePath,
                // BoxFit.contain and no width or height: the whole photo, at
                // its own aspect ratio, however tall or wide it is. A cover
                // fit here would crop the thing the teacher opened it to see.
                fit: BoxFit.contain,
                source: source,
              ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 44.r,
            color: AppColors.textDisabled,
          ),
          SizedBox(height: AppDimensions.spacing12),
          Text(
            'evidence.photo_unavailable'.tr(),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

/// The corner glyph that says a thumbnail opens.
///
/// SHOWN ON THE THUMBNAIL, because a tap target with no affordance is one
/// nobody finds. The reference app puts the same expand icon in the same
/// corner, and it is the only thing distinguishing a photo you can open from
/// one that is merely displayed.
class TcExpandBadge extends StatelessWidget {
  const TcExpandBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.fullscreen_rounded,
        size: 16.r,
        color: AppColors.white,
      ),
    );
  }
}
