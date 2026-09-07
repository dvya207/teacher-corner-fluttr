import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// A step's YouTube video, played inside the tab.
///
/// THE THUMBNAIL COMES FIRST AND THE PLAYER ONLY AFTER A TAP. Not a styling
/// choice. Mounting the iframe player costs a webview and a network round trip
/// on a phone whose whole job for the next ten minutes is a science class, and
/// a teacher swiping through six steps to find the one they want would pay
/// that on every step they passed through. The thumbnail is one cached image;
/// the player exists only once someone has said they want to watch.
///
/// It also puts the tap where the teacher expects it. Screen one of this
/// activity showed a card reading "Opens in another app", and the video played
/// in YouTube, over the app, with the class waiting while the teacher found
/// their way back.
class YoutubeContentView extends StatefulWidget {
  const YoutubeContentView({
    super.key,
    required this.videoId,
    this.autoPlay = false,
  });

  /// The eleven-character id, already validated by [ResolvedResource].
  final String videoId;

  /// Skips the thumbnail and mounts the player straight away. Off by default,
  /// and only ever set where a teacher has already asked for the video.
  final bool autoPlay;

  @override
  State<YoutubeContentView> createState() => _YoutubeContentViewState();
}

class _YoutubeContentViewState extends State<YoutubeContentView> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) _start();
  }

  @override
  void didUpdateWidget(YoutubeContentView old) {
    super.didUpdateWidget(old);
    // A tab reused for a different video: the old controller is still pointed
    // at the old id and would keep playing it behind the new thumbnail.
    if (old.videoId != widget.videoId) {
      _controller?.close();
      _controller = null;
      if (widget.autoPlay) _start();
    }
  }

  void _start() {
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        // The teacher is projecting or holding the phone up to a group. The
        // related-video grid at the end of a video is the last thing that
        // should be on screen in front of a class.
        showVideoAnnotations: false,
        strictRelatedVideos: true,
        enableCaption: false,
      ),
    );
    setState(() {});
  }

  @override
  void dispose() {
    // Closes the webview too. Left open, the audio outlives the screen.
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _Thumbnail(videoId: widget.videoId, onPlay: _start),
        ),
      );
    }

    // NO SCAFFOLD WRAPPER, which is worth stating because the package's own
    // older examples all have one. As of youtube_player_iframe 6,
    // `YoutubePlayerScaffold` is deprecated: the player handles fullscreen
    // itself through an OverlayPortal, with no SystemChrome calls. So the
    // fullscreen button above works from here, and wrapping it would only add
    // a deprecated widget managing orientation nobody asked it to manage.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubePlayer(controller: controller, aspectRatio: 16 / 9),
      ),
    );
  }
}

/// The still frame, with the play button over it.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.videoId, required this.onPlay});

  final String videoId;
  final VoidCallback onPlay;

  /// `hqdefault` rather than `maxresdefault`, which does not exist for every
  /// video and 404s to a blank box when it does not.
  String get _url => 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'lu.play_video'.tr(),
      child: GestureDetector(
        onTap: onPlay,
        child: ColoredBox(
          color: AppColors.textPrimary,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: _url,
                fit: BoxFit.cover,
                // NO ERROR ICON. A missing thumbnail says nothing about
                // whether the video plays, and the play button on top is the
                // only part that has to be visible for this to work.
                errorWidget: (_, _, _) => const SizedBox.shrink(),
                placeholder: (_, _) => const SizedBox.shrink(),
              ),
              Center(
                child: Container(
                  width: 64.r,
                  height: 64.r,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.white,
                    size: 40.r,
                  ),
                ),
              ),
              Positioned(
                left: AppDimensions.spacing12,
                bottom: AppDimensions.spacing12,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing8,
                    vertical: AppDimensions.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusInput,
                    ),
                  ),
                  child: Text(
                    'lu.tap_to_play'.tr(),
                    style: AppTypography.tiny.copyWith(color: AppColors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
