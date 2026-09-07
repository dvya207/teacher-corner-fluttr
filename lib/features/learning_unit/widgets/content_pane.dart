import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/assignment.dart';
import '../../../core/models/learning_unit_additional_resource.dart';
import '../../../core/models/resource_kind.dart';
import '../../../core/models/workflow.dart';
import '../../../core/services/storage_file_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tc_button.dart';
import '../../../core/widgets/tc_empty_state.dart';
import 'resource_view.dart';

/// Opens a resolved resource. Injected so a test never launches anything.
typedef ResourceLauncher = Future<bool> Function(Uri url);

/// One tab's worth of content inside a workflow step.
///
/// Keeps itself alive. Combined with the [IndexedStack] its parent uses, that
/// means switching tabs and coming back does not tear the pane down and rebuild
/// it: a destroyed tab is a re-resolved image and a re-downloaded file.
class ContentPane extends StatefulWidget {
  const ContentPane({
    super.key,
    required this.content,
    this.resolvedPath,
    this.additionalResources = const [],
    this.assignment,
    this.onOpenQuiz,
    this.formBuilder,
    this.loadFailed = false,
    this.reloading = false,
    this.onRetryLoad,
    this.evidenceBuilder,
    this.fileSource,
    this.launcher,
    this.isActive = true,
  });

  final WorkflowContent content;

  /// Where the file actually is, resolved by the provider from
  /// `learningUnitResources`. Null when nothing is uploaded for this content.
  ///
  /// PASSED IN RATHER THAN LOOKED UP. The pane is handed one content and knows
  /// nothing about which learning unit it belongs to, and giving it the
  /// resources collection to search would put a Firestore shape inside a
  /// widget.
  final String? resolvedPath;

  /// The unit's free-form extras, when this content is the slot that lists
  /// them. Resolved by the provider; see
  /// `LearningUnitProvider.additionalResourcesFor`.
  final List<LearningUnitAdditionalResource> additionalResources;

  /// The assignment behind a quiz or form step, when it was readable.
  final Assignment? assignment;

  /// Supplied for a quiz step. Null for every other content, which is also how
  /// the pane knows not to offer the button.
  final void Function(Assignment assignment)? onOpenQuiz;

  /// Supplied for a form step. Built by the screen, which owns the ids the
  /// submission is addressed with.
  final Widget Function(BuildContext context, Assignment assignment)?
  formBuilder;

  /// True when the assignment behind this content could not be READ, as
  /// distinct from not existing. Only then is a Retry worth offering.
  final bool loadFailed;

  final bool reloading;

  /// Retries just the assignments, leaving the rest of the activity alone.
  final Future<void> Function()? onRetryLoad;

  /// Supplied for an upload assignment. Left null the pane says so rather than
  /// rendering an empty box.
  final WidgetBuilder? evidenceBuilder;

  /// Injected by tests so a pane can render without Firebase Storage.
  ///
  /// Reaches the viewers as well as the images now: a PDF is downloaded
  /// through it and a cached mp4 found through it.
  final StorageFileSource? fileSource;

  /// Injected by tests. Production hands the URL to the system.
  final ResourceLauncher? launcher;

  /// Whether this is the tab the teacher is looking at.
  ///
  /// LOAD-BEARING, NOT AN OPTIMISATION. Its parent is an [IndexedStack], which
  /// BUILDS every tab and paints one. That was harmless while a pane was a
  /// card with an Open button. Now a pane mounts a PDF renderer, a video
  /// player or a webview, so a five-tab step was mounting five native views
  /// and starting five downloads the moment a teacher opened the step, on
  /// school wifi, to show them one. On a low-end phone the platform views
  /// contend and some of them simply never draw.
  ///
  /// So a pane renders nothing until its tab is first selected, and everything
  /// after. See [_ContentPaneState._hasBeenActive] for why it never goes back.
  final bool isActive;

  @override
  State<ContentPane> createState() => _ContentPaneState();
}

class _ContentPaneState extends State<ContentPane>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _openingPath;

  /// Once true, never false again.
  ///
  /// THE WHOLE POINT OF THE KEEP-ALIVE. Tearing a pane down on tab change is
  /// what the [IndexedStack] was chosen to avoid: a destroyed tab is a
  /// re-downloaded PDF and a video that loses its position. So a visited tab
  /// stays built, and only a tab nobody has opened yet costs nothing.
  late bool _hasBeenActive = widget.isActive;

  StorageFileSource get _source =>
      widget.fileSource ?? FirebaseStorageFileSource.instance;

  /// True for a path that is already a URL, as the video and social entries
  /// are: those hold a YouTube link, while the guides and reels hold a
  /// Storage path that has to be resolved to a download URL first.
  bool _isDirectUrl(String? path) {
    final value = path?.trim().toLowerCase() ?? '';
    return value.startsWith('http://') || value.startsWith('https://');
  }

  @override
  void didUpdateWidget(ContentPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_hasBeenActive) {
      setState(() => _hasBeenActive = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Required by the mixin.
    super.build(context);

    // Never opened. Nothing is fetched and no platform view is created; the
    // box is here only so the IndexedStack has a child to size.
    if (!_hasBeenActive) return const SizedBox.shrink();

    final content = widget.content;

    if (content.isFormAssignment) {
      final form = widget.assignment;
      final builder = widget.formBuilder;
      if (form == null || builder == null) {
        return _Unreachable(
          icon: Icons.fact_check_outlined,
          title: widget.loadFailed
              ? 'lu.assignment_offline_title'
              : 'lu.form_empty_title',
          subtitle: widget.loadFailed
              ? 'lu.assignment_offline_subtitle'
              : 'lu.form_empty_subtitle',
          busy: widget.reloading,
          onRetry: widget.loadFailed ? widget.onRetryLoad : null,
        );
      }
      return builder(context, form);
    }

    if (content.isQuizAssignment) {
      if (widget.assignment == null) {
        return _Unreachable(
          icon: Icons.quiz_outlined,
          title: widget.loadFailed
              ? 'lu.assignment_offline_title'
              : 'lu.quiz_unavailable_title',
          subtitle: widget.loadFailed
              ? 'lu.assignment_offline_subtitle'
              : 'lu.quiz_unavailable_subtitle',
          busy: widget.reloading,
          onRetry: widget.loadFailed ? widget.onRetryLoad : null,
        );
      }
      return _QuizCard(
        assignment: widget.assignment,
        onOpen: widget.onOpenQuiz,
      );
    }

    if (content.isUploadAssignment) {
      final builder = widget.evidenceBuilder;
      if (builder != null) return builder(context);
      return TcEmptyState(
        icon: Icons.photo_camera_outlined,
        title: 'lu.evidence'.tr(),
        subtitle: 'lu.no_content_subtitle'.tr(),
      );
    }

    final path = widget.resolvedPath?.trim();

    // WHAT IT IS, decided by the value itself rather than by the slot that
    // held it. See [ResolvedResource]: `graphics.headlineImage` holds a PDF in
    // live data, so trusting the category here drew a PDF as a broken image.
    final resolved = ResolvedResource.of(path);

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
          if (widget.additionalResources.isNotEmpty)
            // A LIST, not one card. This slot points at everything the author
            // attached rather than at a single named file, and there can be
            // several of different kinds.
            for (var i = 0; i < widget.additionalResources.length; i++) ...[
              if (i > 0) SizedBox(height: AppDimensions.spacing12),
              _ExtraCard(
                resource: widget.additionalResources[i],
                busy: _openingPath == widget.additionalResources[i].resourcePath,
                fileSource: widget.fileSource,
                onOpen: () => _openPath(
                  widget.additionalResources[i].resourcePath,
                ),
              ),
            ]
          else if (resolved == null)
            // Nothing uploaded for this content yet. Distinct from a failure:
            // the step declares the slot, and the web app fills it later.
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimensions.spacing24),
              child: Text(
                'lu.content_unavailable'.tr(),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            // RENDERED HERE, not handed to the phone. One widget for all of
            // it, because the pane no longer needs to know a video from a
            // guide; that is the classifier's job and the viewers'.
            ResourceView(
              resource: resolved,
              source: widget.fileSource,
              onOpenExternally: () => _openPath(path),
            ),
        ],
      ),
    );
  }

  /// Hands the resource to the system. THE FALLBACK NOW, NOT THE PLAN.
  ///
  /// This used to be how every content was shown, on the reasoning that three
  /// embedded viewers meant three dependencies and three sets of failure modes
  /// on a low-end classroom phone. What that reasoning left out is the teacher:
  /// they are mid-lesson with the class waiting, and an activity guide that
  /// opens in Chrome is a trip out of the app they have to find their way back
  /// from. The viewers are in the app now.
  ///
  /// It survives for the cases where nothing in the app can help: a slot
  /// holding a plain web page, a Drive file behind a sign-in wall, and a PDF
  /// the native renderer chokes on, where a browser genuinely does better.
  Future<void> _openPath(String? raw) async {
    final path = raw?.trim();
    if (path == null || path.isEmpty || _openingPath != null) return;

    setState(() => _openingPath = path);
    try {
      // A Storage path is not a URL. It has to be resolved to a download URL,
      // which carries the access token, before anything can open it.
      final url = _isDirectUrl(path) ? path : await _source.resolve(path);
      final launcher =
          widget.launcher ??
          (Uri uri) =>
              launchUrl(uri, mode: LaunchMode.externalApplication);
      final ok = await launcher(Uri.parse(url));
      if (!ok && mounted) _sayItFailed();
    } catch (e) {
      debugPrint('ContentPane: could not open $path: $e');
      if (mounted) _sayItFailed();
    } finally {
      if (mounted) setState(() => _openingPath = null);
    }
  }

  void _sayItFailed() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('lu.open_failed'.tr())));
  }
}

/// One of the unit's free-form extras: its own title, its kind, and the file
/// itself once asked for.
///
/// COLLAPSED UNTIL TAPPED, unlike the single resource above it. This slot is a
/// LIST, and live units hang several things off it. Mounting a video player
/// and two 480-tall PDF viewers the moment the tab opens would cost three
/// downloads a teacher did not ask for and bury the titles they are scanning
/// to find the one they want. So the row stays a row, and expands in place.
class _ExtraCard extends StatefulWidget {
  const _ExtraCard({
    required this.resource,
    required this.busy,
    required this.onOpen,
    this.fileSource,
  });

  final LearningUnitAdditionalResource resource;
  final bool busy;
  final Future<void> Function() onOpen;

  /// Passed to the inline viewer. Injected by tests.
  final StorageFileSource? fileSource;

  @override
  State<_ExtraCard> createState() => _ExtraCardState();
}

class _ExtraCardState extends State<_ExtraCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final resource = widget.resource;
    final kind = resource.fileExtension?.trim();
    final description = resource.description?.trim();
    final resolved = ResolvedResource.of(resource.resourcePath);

    // Nothing to expand into for a value no viewer handles, so that row keeps
    // the old behaviour and offers the system instead.
    final expandable =
        resolved != null && resolved.kind != ResourceKind.unrenderable &&
        resolved.kind != ResourceKind.webPage;

    return Container(
      padding: EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: expandable ? () => setState(() => _open = !_open) : null,
            child: Row(
              children: [
                Icon(
                  _iconFor(resolved, resource),
                  size: 24.r,
                  color: AppColors.skyBlue,
                ),
                SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        resource.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong,
                      ),
                      // ITS OWN KIND, always. The slot above may have asked
                      // for a PPT and this may be a video; saying so on the
                      // row is what makes showing it anyway honest rather
                      // than misleading.
                      if (kind != null && kind.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(kind.toUpperCase(), style: AppTypography.tiny),
                      ],
                      if (description != null && description.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: AppDimensions.spacing8),
                if (widget.busy)
                  SizedBox(
                    width: 20.r,
                    height: 20.r,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (expandable)
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 24.r,
                    color: AppColors.skyBlue,
                  )
                else
                  IconButton(
                    onPressed: () => widget.onOpen(),
                    tooltip: 'lu.open'.tr(),
                    icon: Icon(
                      Icons.open_in_new_rounded,
                      size: 20.r,
                      color: AppColors.skyBlue,
                    ),
                  ),
              ],
            ),
          ),
          if (_open && resolved != null) ...[
            SizedBox(height: AppDimensions.spacing12),
            ResourceView(
              resource: resolved,
              source: widget.fileSource,
              onOpenExternally: widget.onOpen,
              // Already an explicit request: they tapped the row to open it.
              autoPlay: true,
            ),
          ],
        ],
      ),
    );
  }

  /// The glyph says what the row will show, read off the file rather than off
  /// the `type` field, which live data fills in loosely.
  IconData _iconFor(
    ResolvedResource? resolved,
    LearningUnitAdditionalResource resource,
  ) {
    switch (resolved?.kind) {
      case ResourceKind.youTube:
      case ResourceKind.videoFile:
        return Icons.play_circle_outline_rounded;
      case ResourceKind.image:
        return Icons.image_outlined;
      case ResourceKind.pdf:
        return Icons.picture_as_pdf_outlined;
      case ResourceKind.document:
      case ResourceKind.googleDrive:
        return Icons.slideshow_outlined;
      case ResourceKind.webPage:
        return Icons.link_rounded;
      case ResourceKind.unrenderable:
      case null:
        return (resource.type ?? '').toUpperCase() == 'VIDEO'
            ? Icons.play_circle_outline_rounded
            : Icons.description_outlined;
    }
  }
}

/// A quiz step: what the quiz is, and the way into it.
///
/// NOT THE QUIZ ITSELF. The player is a full screen with its own progress bar,
/// timing and submission rules, and running it inside a tab of a step would
/// give a teacher two nested sets of navigation to escape from.
class _QuizCard extends StatelessWidget {
  const _QuizCard({required this.assignment, required this.onOpen});

  final Assignment? assignment;
  final void Function(Assignment assignment)? onOpen;

  @override
  Widget build(BuildContext context) {
    // Never null: the pane handles that case before building this card, so it
    // can tell a failed read from a missing document.
    final quiz = assignment!;

    final meta = [
      'quizzes.questions'.tr(args: ['${quiz.questions.length}']),
      if (quiz.totalMinutes > 0)
        'lu.duration'.tr(args: ['${quiz.totalMinutes}']),
    ].join(' · ');

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(AppDimensions.spacing16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      size: 24.r,
                      color: AppColors.skyBlue,
                    ),
                    SizedBox(width: AppDimensions.spacing12),
                    Expanded(
                      child: Text(
                        quiz.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(meta, style: AppTypography.tiny),
                SizedBox(height: AppDimensions.spacing16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpen == null ? null : () => onOpen!(quiz),
                    icon: Icon(Icons.play_arrow_rounded, size: 18.r),
                    label: Text('lu.open_quiz'.tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A content that cannot be shown, and a Retry when trying again might help.
///
/// ONE WIDGET FOR BOTH REASONS, because the difference that matters to a
/// teacher is whether there is anything they can do. A deleted assignment and
/// an unreachable one look the same on screen; only one of them gets a button.
class _Unreachable extends StatelessWidget {
  const _Unreachable({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44.r, color: AppColors.textTertiary),
            SizedBox(height: AppDimensions.spacing16),
            Text(
              title.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.sectionTitle,
            ),
            SizedBox(height: AppDimensions.spacing8),
            Text(
              subtitle.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: AppDimensions.spacing24),
              TcButton(
                label: 'common.retry'.tr(),
                isLoading: busy,
                onPressed: onRetry!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
