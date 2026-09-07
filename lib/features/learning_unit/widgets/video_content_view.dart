import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import '../../../core/services/storage_file_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// An mp4, played in the tab. Either a Storage path (`video.tacVideoMp4`,
/// `socialMedia.tacVideoReelMp4`) or a plain video URL.
///
/// CACHE FIRST, THEN STREAM. [StorageFileSource.cached] is network-free, so
/// asking it costs nothing and a reel already on disk plays with no signal at
/// all. On a miss this streams from the tokenised URL rather than downloading
/// the file, because a teacher who has pressed play is waiting: first frame
/// beats a progress bar counting up to a 40MB reel they may watch ten seconds
/// of.
///
/// NOT AUTOPLAY. The classroom is the reason. A video that starts talking
/// because a teacher swiped onto the wrong tab is worse than one extra tap.
class VideoContentView extends StatefulWidget {
  const VideoContentView({
    super.key,
    required this.path,
    required this.isUrl,
    this.source,
  });

  /// A Storage path, or a URL when [isUrl].
  final String path;

  final bool isUrl;

  /// Injected by tests, which have neither Firebase nor a video decoder.
  final StorageFileSource? source;

  @override
  State<VideoContentView> createState() => _VideoContentViewState();
}

class _VideoContentViewState extends State<VideoContentView> {
  VideoPlayerController? _controller;
  bool _loading = true;

  StorageFileSource get _source =>
      widget.source ?? FirebaseStorageFileSource.instance;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(VideoContentView old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _controller?.dispose();
      _controller = null;
      _prepare();
    }
  }

  Future<void> _prepare() async {
    setState(() => _loading = true);
    try {
      final controller = await _open();
      await controller.initialize();
      // The screen may be gone by now: a teacher who taps a tab and moves on
      // leaves an initialised player with nothing to draw it.
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      debugPrint('VideoContentView: could not open ${widget.path}: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<VideoPlayerController> _open() async {
    if (widget.isUrl) {
      return VideoPlayerController.networkUrl(Uri.parse(widget.path));
    }
    final File? onDisk = await _source.cached(widget.path);
    if (onDisk != null) return VideoPlayerController.file(onDisk);
    return VideoPlayerController.networkUrl(
      Uri.parse(await _source.resolve(widget.path)),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _Frame(
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return _Frame(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.spacing16),
            child: Text(
              'lu.video_failed'.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.white),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          child: AspectRatio(
            // A stream that reports no size yet would divide by zero.
            aspectRatio: controller.value.aspectRatio <= 0
                ? 16 / 9
                : controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(controller),
                _PlayOverlay(controller: controller),
              ],
            ),
          ),
        ),
        SizedBox(height: AppDimensions.spacing8),
        VideoProgressIndicator(
          controller,
          allowScrubbing: true,
          colors: VideoProgressColors(
            playedColor: AppColors.skyBlue,
            bufferedColor: AppColors.borderLight,
            backgroundColor: AppColors.borderSubtle,
          ),
        ),
      ],
    );
  }
}

/// The play and pause control, drawn over the frame.
///
/// A LISTENABLEBUILDER RATHER THAN setState. The controller ticks several times
/// a second while playing, and rebuilding the whole pane on every tick is how a
/// low-end phone starts dropping frames on a screen that is mostly static.
class _PlayOverlay extends StatelessWidget {
  const _PlayOverlay({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final playing = controller.value.isPlaying;
        return Semantics(
          button: true,
          label: playing ? 'lu.pause_video'.tr() : 'lu.play_video'.tr(),
          child: GestureDetector(
            onTap: () async {
              if (playing) {
                await controller.pause();
              } else {
                // Replays rather than sitting at the end doing nothing.
                if (controller.value.position >= controller.value.duration) {
                  await controller.seekTo(Duration.zero);
                }
                await controller.play();
              }
            },
            child: Container(
              // Transparent, but it has to be a hit target across the whole
              // frame, which an Icon alone is not.
              color: Colors.transparent,
              alignment: Alignment.center,
              child: AnimatedOpacity(
                // Out of the way while playing, so it is not sitting over the
                // thing a class is watching.
                opacity: playing ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 56.r,
                  height: 56.r,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.white,
                    size: 34.r,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A 16:9 dark box, so loading and failure occupy exactly the space the video
/// will, and the tab does not jump when it arrives.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(color: AppColors.textPrimary, child: child),
      ),
    );
  }
}
