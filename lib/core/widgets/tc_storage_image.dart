import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/storage_image_source.dart';
import '../theme/app_colors.dart';

/// Renders an image identified by a Cloud Storage PATH rather than a URL.
///
/// Order of operations matters and is the reason this widget exists:
///
///   1. ask the file cache for the path. A hit renders straight off disk, with
///      no `getDownloadURL()` call, so a cached image costs nothing and works
///      offline;
///   2. only on a miss, resolve a download URL and hand it to
///      [CachedNetworkImage] with `cacheKey` set to the PATH. That is what
///      makes step 1 hit next time; keyed on the URL it never would, because
///      every resolution returns a different token.
class TcStorageImage extends StatefulWidget {
  const TcStorageImage({
    super.key,
    required this.storagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.source,
  });

  /// A Storage path such as `luImages/mps_200x200.png`. Null or blank renders
  /// the placeholder without any lookup at all.
  final String? storagePath;

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Injected by tests. Production uses the shared Firebase-backed source.
  final StorageImageSource? source;

  @override
  State<TcStorageImage> createState() => _TcStorageImageState();
}

class _TcStorageImageState extends State<TcStorageImage> {
  Future<_Resolved?>? _future;

  StorageImageSource get _source =>
      widget.source ?? FirebaseStorageImageSource.instance;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(TcStorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-resolve only when the identity actually changed. Resolving on every
    // rebuild is how a list ends up re-requesting on scroll.
    if (oldWidget.storagePath != widget.storagePath) {
      _future = _resolve();
    }
  }

  Future<_Resolved?> _resolve() async {
    final path = widget.storagePath?.trim();
    if (path == null || path.isEmpty) return null;

    final cached = await _source.cached(path);
    if (cached != null) return _FromCache(cached);

    final url = await _source.resolve(path);
    return _FromNetwork(url, _source.cacheKey(path));
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(8.r);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: FutureBuilder<_Resolved?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _Placeholder();
            }
            if (snapshot.hasError || snapshot.data == null) {
              // A missing or unreadable image degrades to a neutral tile. It is
              // never worth failing a whole card over cover art.
              return const _Placeholder(failed: true);
            }
            return switch (snapshot.data!) {
              _FromCache(file: final file) => Image.file(
                  file,
                  width: widget.width,
                  height: widget.height,
                  fit: widget.fit,
                  errorBuilder: (_, _, _) => const _Placeholder(failed: true),
                ),
              _FromNetwork(url: final url, key: final key) =>
                CachedNetworkImage(
                  imageUrl: url,
                  // The PATH, not the URL. This is the line that makes the
                  // cache work at all.
                  cacheKey: key,
                  width: widget.width,
                  height: widget.height,
                  fit: widget.fit,
                  placeholder: (_, _) => const _Placeholder(),
                  errorWidget: (_, _, _) => const _Placeholder(failed: true),
                ),
            };
          },
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.borderSubtle,
      child: Center(
        child: Icon(
          failed ? Icons.image_not_supported_outlined : Icons.image_outlined,
          size: 20.r,
          color: AppColors.textDisabled,
        ),
      ),
    );
  }
}

sealed class _Resolved {
  const _Resolved();
}

class _FromCache extends _Resolved {
  const _FromCache(this.file);
  final File file;
}

class _FromNetwork extends _Resolved {
  const _FromNetwork(this.url, this.key);
  final String url;
  final String key;
}
