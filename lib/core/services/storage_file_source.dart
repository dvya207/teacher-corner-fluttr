import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Everything the app needs from Cloud Storage, narrow enough that a test can
/// implement it without Firebase.
///
/// NAMED FOR FILES RATHER THAN IMAGES since the content panes started
/// rendering PDFs and mp4s in-app: the same token and cache-key rules below
/// govern a 30MB guide exactly as they govern a thumbnail, and a second
/// service would have been a second cache with the same subtle rules to get
/// wrong twice.
///
/// The split into two methods is the whole point. Firebase mints a fresh access
/// token into every `getDownloadURL()` result, so the same file yields a
/// different URL on every call. That has two consequences the production team
/// paid for:
///
///   * the cache MUST be keyed on the Storage PATH, never on the URL, or it
///     never hits and silently re-downloads forever while appearing to work;
///   * the cache MUST be consulted BEFORE resolving a URL, or a fully cached
///     file still costs a network round trip and still fails offline.
///
/// So [cached] is required to be network-free, and [resolve] is only ever
/// called on a miss.
abstract class StorageFileSource {
  /// A file already on disk for [storagePath], or null when there is none.
  /// Must not touch the network.
  Future<File?> cached(String storagePath);

  /// A fresh, tokenised download URL. Only called after [cached] misses.
  Future<String> resolve(String storagePath);

  /// The file itself on disk, fetched when the cache misses.
  ///
  /// SEPARATE FROM [cached] BECAUSE IT IS ALLOWED TO WAIT. [cached] answers
  /// "is this already here" without touching the network, which is what lets a
  /// widget decide whether to show a spinner at all. This one is the spinner's
  /// job: it returns when the bytes are local, however long that takes.
  ///
  /// Needed because the PDF viewer renders a local file only, and a video
  /// plays from one far more reliably than from a URL whose token expires
  /// mid-stream.
  Future<File> download(String storagePath);

  /// The key under which bytes for [storagePath] are stored. The path itself,
  /// which is the stable identity; the URL is not.
  String cacheKey(String storagePath) => storagePath;
}

/// The real implementation: Firebase Storage plus the shared file cache.
class FirebaseStorageFileSource implements StorageFileSource {
  FirebaseStorageFileSource({
    FirebaseStorage? storage,
    BaseCacheManager? cacheManager,
  })  : _injectedStorage = storage,
        _cache = cacheManager ?? DefaultCacheManager();

  /// Shared instance, so one screen's resolutions are reusable by the next.
  static final FirebaseStorageFileSource instance =
      FirebaseStorageFileSource();

  final FirebaseStorage? _injectedStorage;
  final BaseCacheManager _cache;

  /// Resolved lazily: `FirebaseStorage.instance` calls `Firebase.app()`, which
  /// throws where Firebase was never initialised.
  late final FirebaseStorage _storage =
      _injectedStorage ?? FirebaseStorage.instance;

  @override
  String cacheKey(String storagePath) => storagePath;

  @override
  Future<File?> cached(String storagePath) async {
    final info = await _cache.getFileFromCache(cacheKey(storagePath));
    return info?.file;
  }

  @override
  Future<String> resolve(String storagePath) =>
      _storage.ref(storagePath).getDownloadURL();

  /// KEYED ON THE PATH, URL RESOLVED SECOND. The same ordering [cached]
  /// depends on, and for the same reason: `getDownloadURL()` mints a new token
  /// every call, so a cache keyed on its result never hits and re-downloads
  /// the guide every time a teacher opens the tab.
  @override
  Future<File> download(String storagePath) async {
    final key = cacheKey(storagePath);
    final hit = await _cache.getFileFromCache(key);
    if (hit != null) return hit.file;
    return _cache.getSingleFile(await resolve(storagePath), key: key);
  }
}
