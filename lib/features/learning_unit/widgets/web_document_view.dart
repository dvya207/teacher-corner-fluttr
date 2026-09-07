import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/services/storage_file_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tc_button.dart';

/// The two kinds of content nothing on the device can open: a slide deck or an
/// Office document, and a Google Drive link.
///
/// RENDERED BY SOMEONE ELSE'S SERVER, and that is the honest description.
/// Android has no PowerPoint or Word renderer, and shipping one is a
/// document-conversion library for two slots in the schema. So the file's
/// download URL is handed to Google's document viewer and the result is shown
/// in a webview.
///
/// WHAT THAT COSTS, WRITTEN DOWN because it is a real trade and not free: the
/// tokenised Storage URL is sent to `docs.google.com`, which fetches the file
/// from Firebase to render it. The file is ThinkTac's own teaching material
/// rather than anything about a child, and the URL's token is read-only and
/// scoped to that one object, but a deck does leave Firebase for another Google
/// service and somebody should have decided that on purpose. If that is not
/// wanted, this widget is the one place to change: drop it and these slots go
/// back to [ResourceKind.webPage] handling, which opens them in the browser.
///
/// A DRIVE LINK IS NOT CONVERTED, only reshaped. `/file/d/<id>/view` becomes
/// `/file/d/<id>/preview`, which is the embeddable form; the file still has to
/// be readable by whoever is signed in, and Drive shows its own sign-in page
/// when it is not. That page inside a webview is a dead end, which is why the
/// external fallback is always offered here rather than only on failure.
class WebDocumentView extends StatefulWidget {
  const WebDocumentView({
    super.key,
    required this.path,
    required this.isUrl,
    this.source,
    this.onOpenExternally,
  });

  /// A Storage path to an Office file, or a Drive or Docs URL when [isUrl].
  final String path;

  final bool isUrl;

  /// Injected by tests, which have no Firebase.
  final StorageFileSource? source;

  /// Always offered, for the Drive sign-in reason above.
  final Future<void> Function()? onOpenExternally;

  @override
  State<WebDocumentView> createState() => _WebDocumentViewState();
}

class _WebDocumentViewState extends State<WebDocumentView> {
  WebViewController? _controller;
  bool _loading = true;
  bool _failed = false;

  StorageFileSource get _source =>
      widget.source ?? FirebaseStorageFileSource.instance;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(WebDocumentView old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final target = await _viewerUrl();
      final controller = WebViewController()
        // The viewers are JavaScript applications; without this the webview
        // renders a blank page and reports nothing.
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
            onWebResourceError: (error) {
              debugPrint('WebDocumentView: ${widget.path}: ${error.description}');
              // ONLY THE MAIN DOCUMENT. A viewer page pulls in fonts and
              // analytics that fail routinely without affecting what a teacher
              // sees, and treating those as failure would replace a working
              // deck with an error card.
              if (error.isForMainFrame ?? true) {
                if (mounted) {
                  setState(() {
                    _failed = true;
                    _loading = false;
                  });
                }
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(target));
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      debugPrint('WebDocumentView: could not prepare ${widget.path}: $e');
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  /// The address the webview is pointed at.
  Future<String> _viewerUrl() async {
    if (widget.isUrl) return _drivePreview(widget.path);
    final url = await _source.resolve(widget.path);
    return 'https://docs.google.com/gview'
        '?embedded=true&url=${Uri.encodeComponent(url)}';
  }

  /// Drive's embeddable form of whatever shape the link arrived in.
  ///
  /// Left alone when the id cannot be found, because a wrong guess at a Drive
  /// URL is a 404 inside a webview, and the original at least loads something
  /// a teacher can read.
  static String _drivePreview(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    final segments = uri.pathSegments;
    final d = segments.indexOf('d');
    if (d != -1 && d + 1 < segments.length) {
      return 'https://drive.google.com/file/d/${segments[d + 1]}/preview';
    }
    final id = uri.queryParameters['id'];
    if (id != null && id.isNotEmpty) {
      return 'https://drive.google.com/file/d/$id/preview';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 480.h,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(color: AppColors.borderLight),
          ),
          clipBehavior: Clip.antiAlias,
          child: _failed
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.spacing16),
                    child: Text(
                      'lu.document_view_failed'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                )
              : Stack(
                  children: [
                    if (controller != null) WebViewWidget(controller: controller),
                    if (_loading)
                      const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
        ),
        if (_failed) ...[
          SizedBox(height: AppDimensions.spacing12),
          TcButton(label: 'common.retry'.tr(), onPressed: _prepare),
        ],
        if (widget.onOpenExternally != null) ...[
          SizedBox(height: AppDimensions.spacing8),
          TextButton.icon(
            onPressed: () => widget.onOpenExternally!(),
            icon: Icon(Icons.open_in_new_rounded, size: 18.r),
            label: Text('lu.open_externally'.tr()),
          ),
        ],
      ],
    );
  }
}
