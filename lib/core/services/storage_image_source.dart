import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Everything the image widget needs from Cloud Storage, narrow enough that a
/// test can implement it without Firebase.
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
abstract class StorageImageSource {
  /// A file already on disk for [storagePath], or null when there is none.
  /// Must not touch the network.
  Future<File?> cached(String storagePath);

  /// A fresh, tokenised download URL. Only called after [cached] misses.
  Future<String> resolve(String storagePath);

  /// The key under which bytes for [storagePath] are stored. The path itself,
  /// which is the stable identity; the URL is not.
  String cacheKey(String storagePath) => storagePath;
}

/// The real implementation: Firebase Storage plus the shared file cache.
class FirebaseStorageImageSource implements StorageImageSource {
  FirebaseStorageImageSource({
    FirebaseStorage? storage,
    BaseCacheManager? cacheManager,
  })  : _injectedStorage = storage,
        _cache = cacheManager ?? DefaultCacheManager();

  /// Shared instance, so one screen's resolutions are reusable by the next.
  static final FirebaseStorageImageSource instance =
      FirebaseStorageImageSource();

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
}
