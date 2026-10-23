import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/services/storage_file_source.dart';
import 'package:tc_starter/core/widgets/tc_photo_viewer.dart';

import '../../support/pump_app.dart';

/// Resolves a path to a URL and never to a file, which is all the viewer needs
/// from Storage. No bytes are fetched: the image widget's own loading state is
/// what renders, and what is under test here is the viewer's chrome and paging.
class _StubSource implements StorageFileSource {
  final List<String> resolved = [];

  @override
  Future<File?> cached(String storagePath) async => null;

  @override
  Future<String> resolve(String storagePath) async {
    resolved.add(storagePath);
    return 'https://storage.example/$storagePath';
  }

  @override
  Future<File> download(String storagePath) async =>
      throw StateError('no file system in this test');

  @override
  String cacheKey(String storagePath) => storagePath;
}

void main() {
  setUp(initLocalizationForTest);

  group('what the viewer shows', () {
    testWidgets('a single photo gets no counter, because there is no set', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        child: TcPhotoViewer(
          photos: const [TcPhoto.storage('teacher_submissions/uid/a.jpg')],
          source: _StubSource(),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Photo'), findsNothing);
      // The way out is always there, floated over the photo rather than in a
      // bar of its own: this is an overlay on the screen the teacher was on,
      // not a page of its own.
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(Scaffold), findsNothing);
    });

    testWidgets('several photos are counted, starting at the one tapped', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        child: TcPhotoViewer(
          photos: const [
            TcPhoto.storage('a.jpg'),
            TcPhoto.storage('b.jpg'),
            TcPhoto.storage('c.jpg'),
          ],
          initialIndex: 1,
          source: _StubSource(),
        ),
      );
      await tester.pump();

      // NOT "Photo 1 of 3". A teacher who tapped the second thumbnail is
      // looking at the second photo, and the label has to agree with the
      // screen or it undermines the count.
      expect(find.text('Photo 2 of 3'), findsOneWidget);
    });

    testWidgets('an out-of-range index is survived, not thrown on', (
      tester,
    ) async {
      // showTcPhotoViewer clamps it; this asserts the widget itself tolerates
      // one anyway, since a caller can construct it directly. Reachable if a
      // photo is removed between the grid building and the tap landing, which
      // is one frame's worth of window but a crash either way.
      await pumpScreen(
        tester,
        child: TcPhotoViewer(
          photos: const [TcPhoto.storage('a.jpg')],
          initialIndex: 7,
          source: _StubSource(),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('zooming', () {
    testWidgets('every photo is wrapped in an InteractiveViewer', (
      tester,
    ) async {
      // THE REASON THE SCREEN EXISTS. Without pinch-zoom this is a bigger
      // thumbnail, and a teacher still cannot tell whether the apparatus in
      // the corner of the frame worked.
      await pumpScreen(
        tester,
        child: TcPhotoViewer(
          photos: const [TcPhoto.storage('a.jpg')],
          source: _StubSource(),
        ),
      );
      await tester.pump();

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.maxScale, greaterThan(1));
    });
  });

  group('opening it', () {
    testWidgets('an empty set opens nothing rather than a blank screen', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTcPhotoViewer(context, photos: const []),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(TcPhotoViewer), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a set opens the viewer at the requested photo', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTcPhotoViewer(
              context,
              photos: const [TcPhoto.storage('a.jpg'), TcPhoto.storage('b.jpg')],
              initialIndex: 1,
              source: null,
            ),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(TcPhotoViewer), findsOneWidget);
      expect(find.text('Photo 2 of 2'), findsOneWidget);
      // The screen it opened from is still mounted underneath, which is the
      // whole reason this is a dialog and not a pushed page.
      expect(find.text('open'), findsOneWidget);
    });
  });
}
