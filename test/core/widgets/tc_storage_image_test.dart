import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/services/storage_file_source.dart';
import 'package:tc_starter/core/widgets/tc_storage_image.dart';

import '../../support/pump_app.dart';

/// A 1x1 transparent PNG, so Image.file has something real to decode.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Records exactly which of the two calls were made, which is the contract
/// under test: a cache hit must cost NO url resolution.
class RecordingSource implements StorageFileSource {
  RecordingSource({this.cachedFile, this.url = 'https://example/x?token=abc',
      this.resolveThrows});

  final File? cachedFile;
  final String url;
  final Object? resolveThrows;

  final List<String> cachedCalls = [];
  final List<String> resolveCalls = [];
  final List<String> keyCalls = [];
  final List<String> downloadCalls = [];

  @override
  Future<File?> cached(String storagePath) async {
    cachedCalls.add(storagePath);
    return cachedFile;
  }

  @override
  Future<String> resolve(String storagePath) async {
    resolveCalls.add(storagePath);
    if (resolveThrows != null) throw resolveThrows!;
    return url;
  }

  /// Unused by the image widget, which wants a URL rather than a file. Here
  /// because the interface serves the PDF and video viewers too.
  @override
  Future<File> download(String storagePath) async {
    downloadCalls.add(storagePath);
    final file = cachedFile;
    if (file == null) throw StateError('nothing to download');
    return file;
  }

  @override
  String cacheKey(String storagePath) {
    keyCalls.add(storagePath);
    return storagePath;
  }
}

const _path = 'luImages/mps_200x200.png';

void main() {
  setUp(initLocalizationForTest);

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tc_storage_image');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File aCachedFile() {
    final file = File('${tempDir.path}/cached.png')
      ..writeAsBytesSync(_pngBytes);
    return file;
  }

  Future<void> pumpImage(
    WidgetTester tester,
    RecordingSource source, {
    String? path = _path,
  }) =>
      pumpScreen(
        tester,
        child: Center(
          child: TcStorageImage(
            storagePath: path,
            width: 80,
            height: 80,
            source: source,
          ),
        ),
      );

  group('the cache is consulted before any URL is resolved', () {
    testWidgets('a cache hit resolves NO download URL at all', (tester) async {
      // The trap: resolving first means a fully cached image still costs a
      // network round trip, and still fails offline.
      final source = RecordingSource(cachedFile: aCachedFile());

      await pumpImage(tester, source);

      expect(source.cachedCalls, [_path]);
      expect(source.resolveCalls, isEmpty);
    });

    testWidgets('a cache miss resolves exactly once', (tester) async {
      final source = RecordingSource();

      await pumpImage(tester, source);

      expect(source.cachedCalls, [_path]);
      expect(source.resolveCalls, [_path]);
    });

    testWidgets('the cache key is the PATH, never the URL', (tester) async {
      // Firebase mints a fresh token into every getDownloadURL result, so a
      // URL-keyed cache never hits and re-downloads forever while looking fine.
      final source = RecordingSource(url: 'https://example/x?token=CHANGES');

      await pumpImage(tester, source);

      expect(source.keyCalls, contains(_path));
      expect(source.cacheKey(_path), _path);
      expect(source.cacheKey(_path), isNot(startsWith('http')));
    });
  });

  group('nothing to load', () {
    testWidgets('a null path touches neither the cache nor the network',
        (tester) async {
      final source = RecordingSource();

      await pumpImage(tester, source, path: null);

      expect(source.cachedCalls, isEmpty);
      expect(source.resolveCalls, isEmpty);
    });

    testWidgets('a blank path touches neither', (tester) async {
      // Every seeded workflow content has resourcePath: '', which is present
      // but useless, and must not become a lookup for "".
      final source = RecordingSource();

      await pumpImage(tester, source, path: '   ');

      expect(source.cachedCalls, isEmpty);
      expect(source.resolveCalls, isEmpty);
    });
  });

  group('not re-resolving needlessly', () {
    testWidgets('a rebuild with the same path does not resolve again',
        (tester) async {
      final source = RecordingSource();
      await pumpImage(tester, source);
      expect(source.resolveCalls, hasLength(1));

      // Force a rebuild of the same widget with identical inputs.
      await pumpImage(tester, source);
      await tester.pumpAndSettle();

      expect(source.resolveCalls, hasLength(1),
          reason: 'resolved again on a plain rebuild');
    });

    testWidgets('changing the path does resolve the new one', (tester) async {
      final source = RecordingSource();
      await pumpImage(tester, source);
      await pumpImage(tester, source, path: 'luImages/other.png');
      await tester.pumpAndSettle();

      expect(source.resolveCalls, [_path, 'luImages/other.png']);
    });
  });

  group('degrading', () {
    testWidgets('a failed resolve shows a placeholder rather than throwing',
        (tester) async {
      final source = RecordingSource(resolveThrows: StateError('no object'));

      await pumpImage(tester, source);

      // Cover art is never worth failing a card over.
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });
  });
}
