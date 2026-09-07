import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/learning_unit_resources.dart';
import 'package:tc_starter/core/models/workflow.dart';
import 'package:tc_starter/core/services/storage_file_source.dart';
import 'package:tc_starter/features/learning_unit/widgets/content_pane.dart';
import 'package:tc_starter/features/learning_unit/widgets/pdf_content_view.dart';
import 'package:tc_starter/features/learning_unit/widgets/youtube_content_view.dart';

import '../../support/pump_app.dart';

/// The resources document for Swimming, in the shape teacher-corner-dev holds.
LearningUnitResources theResources() =>
    LearningUnitResources.fromMap('res1', {
      'resources': {
        'video': {
          'tacVideoDriveUrl': 'https://www.youtube.com/watch?v=Pkh8UtuejGw',
        },
        'tacDev': {'devGuidePdf': 'learningUnits/lu1/Sample.pdf'},
      },
    });

/// The first step's contents, exactly as the workflow stores them: a pointer
/// and an EMPTY resourcePath.
const tacVideo = WorkflowContent(
  contentName: 'Tactivity',
  contentCategory: 'video',
  contentSubCategory: 'tacVideoDriveUrl',
  resourcePath: '',
);

const guide = WorkflowContent(
  contentName: 'Guide',
  contentCategory: 'tacDev',
  contentSubCategory: 'devGuidePdf',
  resourcePath: '',
);

const nothingUploaded = WorkflowContent(
  contentName: 'Material list',
  contentCategory: 'additional resources',
  contentSubCategory: '',
  resourcePath: '',
);

/// Resolves a URL happily, but never produces a file.
///
/// DELIBERATELY, and it is not a shortcut. A widget test has no native PDF
/// renderer and no Storage, so what is worth asserting is that the pane ASKED
/// for the bytes of the right path and mounted the viewer, plus that the
/// viewer's fallback works when the bytes never arrive. Rendering a real page
/// belongs on a device.
class _StubSource implements StorageFileSource {
  static const url = 'https://storage.example/Sample.pdf';
  final List<String> resolved = [];
  final List<String> downloaded = [];

  @override
  Future<File?> cached(String storagePath) async => null;

  @override
  Future<String> resolve(String storagePath) async {
    resolved.add(storagePath);
    return url;
  }

  @override
  Future<File> download(String storagePath) async {
    downloaded.add(storagePath);
    throw StateError('no file system in this test');
  }

  @override
  String cacheKey(String storagePath) => storagePath;
}

Future<void> pumpPane(
  WidgetTester tester, {
  required WorkflowContent content,
  required String? resolvedPath,
  StorageFileSource? source,
  ResourceLauncher? launcher,
  bool loadFailed = false,
  Future<void> Function()? onRetryLoad,
}) => pumpScreen(
  tester,
  child: Scaffold(
    body: ContentPane(
      content: content,
      resolvedPath: resolvedPath,
      fileSource: source,
      launcher: launcher,
      loadFailed: loadFailed,
      onRetryLoad: onRetryLoad,
    ),
  ),
);

const quizContent = WorkflowContent(
  contentName: 'Ans Me',
  contentCategory: 'assignment',
  assignmentType: 'QUIZ',
  assignmentId: 'a1',
);

/// Sterling Point's own slots, verbatim from teacher-corner-dev.
///
/// PINNED AS LIVE DATA, not as a tidy fixture. The video URLs were pasted out
/// of a browser and still carry `&list=` and `&start_radio=1`, and every 3S
/// slot is grade-dependent so its board key holds a `boardGradeResources`
/// document id rather than a file. Both of those are what the tests below are
/// for, and a cleaned-up fixture would assert neither.
LearningUnitResources sterlingPoint() =>
    LearningUnitResources.fromMap('1eXvhUXV7stAgLMV8BA0', {
      'resources': {
        'video': {
          'tacVideoUrl':
              'https://www.youtube.com/watch?v=lY2yjAdbvdQ'
              '&list=RDlY2yjAdbvdQ&start_radio=1',
          'tacVideoMp4': 'learningUnits/2awVLuyYaxFqMFuVp3Ny/Treat you better.mp4',
        },
        '3S': {
          'conceptPostTestQuizPdf': {
            'CBSE': 'X2GPbu1KeM9arUdINweL',
            'ICSE': 'y2XaeClFZOLOVaDIXsqc',
            'universalGradeBoardResourcePath': '',
          },
          'quizzesDev': {'universalGradeBoardResourcePath': ''},
        },
      },
    });

/// The video content as the workflow now stores it, after being repointed from
/// `tacVideoMp4` to the YouTube URL.
const tacVideoUrlContent = WorkflowContent(
  contentName: 'Activity Demonstration video',
  contentCategory: 'video',
  contentSubCategory: 'tacVideoUrl',
  resourcePath: '',
);

void main() {
  setUp(initLocalizationForTest);

  group('Sterling Point, as the database actually holds it', () {
    /// THE TRACKING QUERY IS THE POINT. A link pasted from a browser carries
    /// `&list=` and `&start_radio=1`, and reading the id off the tail of the
    /// string rather than the named parameter would take 'RDlY2yjAdbvdQ' or
    /// nothing. Either mounts a black player that reports no error.
    test('the repointed video slot resolves to the YouTube watch URL', () {
      expect(
        sterlingPoint().pathFor(
          category: tacVideoUrlContent.contentCategory,
          subCategory: tacVideoUrlContent.contentSubCategory,
        ),
        'https://www.youtube.com/watch?v=lY2yjAdbvdQ'
        '&list=RDlY2yjAdbvdQ&start_radio=1',
      );
    });

    testWidgets('and plays it in the tab, not behind an Open button', (
      tester,
    ) async {
      final path = sterlingPoint().pathFor(
        category: tacVideoUrlContent.contentCategory,
        subCategory: tacVideoUrlContent.contentSubCategory,
      );

      await pumpPane(
        tester,
        content: tacVideoUrlContent,
        resolvedPath: path,
      );

      // THE ASSERTION THAT MATTERS. Before the viewers existed this pane
      // rendered a card reading "Opens in another app"; the video played in
      // YouTube, over the app, with the class waiting.
      expect(find.byType(YoutubeContentView), findsOneWidget);
      expect(find.textContaining('Opens in'), findsNothing);
    });

    /// A GRADE-DEPENDENT SLOT HOLDS SIGNPOSTS, NOT FILES. Its board keys carry
    /// `boardGradeResources` document ids, so returning one as a path is what
    /// made the Pre-Test tab report that a PDF was not a file.
    test('a grade-dependent 3S slot yields no direct path', () {
      expect(
        sterlingPoint().pathFor(category: '3S', subCategory: 'conceptPostTestQuizPdf'),
        isNull,
        reason: 'a board key is a document id, not a file',
      );
    });

    test('but it does expose the board document id to follow', () {
      expect(
        sterlingPoint().boardDocIdFor(
          category: '3S',
          subCategory: 'conceptPostTestQuizPdf',
          board: 'CBSE',
        ),
        'X2GPbu1KeM9arUdINweL',
      );
    });

    /// An empty universal path is NOT a file either, and reading it as one drew
    /// a broken viewer on every unfilled slot.
    test('an empty slot yields nothing rather than an empty path', () {
      expect(
        sterlingPoint().pathFor(category: '3S', subCategory: 'quizzesDev'),
        isNull,
      );
    });
  });

  group('the pointer resolves to the upload', () {
    test('a video content finds its YouTube link', () {
      // The step carries category + subCategory and an empty resourcePath; the
      // link lives in learningUnitResources. This pairing is the whole fix.
      expect(
        theResources().pathFor(
          category: tacVideo.contentCategory,
          subCategory: tacVideo.contentSubCategory,
        ),
        'https://www.youtube.com/watch?v=Pkh8UtuejGw',
      );
    });

    test('a content with no subCategory resolves to nothing', () {
      expect(
        theResources().pathFor(
          category: nothingUploaded.contentCategory,
          subCategory: nothingUploaded.contentSubCategory,
        ),
        isNull,
      );
    });
  });

  group('what the pane shows', () {
    testWidgets('nothing uploaded says so rather than rendering blank', (
      tester,
    ) async {
      await pumpPane(
        tester,
        content: nothingUploaded,
        resolvedPath: null,
      );

      expect(find.text('Material list'), findsOneWidget);
      expect(
        find.textContaining('has no text or image attached'),
        findsOneWidget,
      );
      expect(find.text('Open'), findsNothing);
    });

    testWidgets('a YouTube link is playable here, not handed away', (
      tester,
    ) async {
      await pumpPane(
        tester,
        content: tacVideo,
        resolvedPath: 'https://www.youtube.com/watch?v=Pkh8UtuejGw',
      );

      expect(find.text('Tactivity'), findsOneWidget);
      expect(find.byType(YoutubeContentView), findsOneWidget);
      expect(find.text('Tap to play'), findsOneWidget);

      // THE ASSERTION THE WHOLE CHANGE IS FOR. This pane used to read "Opens
      // in your browser" with an Open button under it, and the teacher lost
      // the app mid-lesson to watch a two-minute demonstration.
      expect(find.text('Open'), findsNothing);
      expect(find.text('Opens in your browser'), findsNothing);
    });

    testWidgets('a PDF is rendered here, and its bytes are asked for', (
      tester,
    ) async {
      final source = _StubSource();
      await pumpPane(
        tester,
        content: guide,
        resolvedPath: 'learningUnits/lu1/Sample.pdf',
        source: source,
      );
      await tester.pump();

      expect(find.byType(PdfContentView), findsOneWidget);
      // Downloaded rather than resolved: the native viewer renders a local
      // file, so the pane fetches the bytes instead of minting a URL.
      expect(source.downloaded, ['learningUnits/lu1/Sample.pdf']);
      expect(find.text('Opens in another app'), findsNothing);
    });

    testWidgets('a slot named for an image, holding a PDF, gets the PDF viewer', (
      tester,
    ) async {
      // LIVE DATA, not a hypothetical: graphics.headlineImage holds Sample.pdf
      // in teacher-corner-dev. The old pane trusted the category and drew this
      // through the image widget.
      const headlineImage = WorkflowContent(
        contentName: 'Headline image',
        contentCategory: 'graphics',
        contentSubCategory: 'headlineImage',
        contentType: 'image',
        resourcePath: '',
      );

      await pumpPane(
        tester,
        content: headlineImage,
        resolvedPath: 'learningUnits/cv1lPaUPXTg1EqUSXT0y/Sample.pdf',
        source: _StubSource(),
      );
      await tester.pump();

      expect(find.byType(PdfContentView), findsOneWidget);
    });
  });

  group('an assignment that could not be loaded', () {
    // THE CASE A DROPPED SIGNAL PRODUCES. Firestore serves the steps from its
    // cache, but an assignment never fetched before has nothing cached, so the
    // card is empty for a reason a teacher can actually fix.
    testWidgets('a failed READ offers a Retry', (tester) async {
      var retries = 0;
      await pumpPane(
        tester,
        content: quizContent,
        resolvedPath: null,
        loadFailed: true,
        onRetryLoad: () async => retries++,
      );

      expect(find.textContaining('Cannot reach this right now'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retries, 1);
    });

    testWidgets('a MISSING assignment does not, because retrying cannot help', (
      tester,
    ) async {
      await pumpPane(
        tester,
        content: quizContent,
        resolvedPath: null,
        loadFailed: false,
      );

      expect(find.text('Quiz unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });

  /// What is left of the handoff, now that the viewers do the rest.
  group('the way out, for what no viewer can show', () {
    /// A slot holding a plain page rather than a file. Nothing in the app
    /// renders a website, so this is the one content that still gets a button.
    const webPage = WorkflowContent(
      contentName: 'Programme page',
      contentCategory: 'tacDev',
      contentSubCategory: 'devGuideUrl',
      resourcePath: '',
    );

    testWidgets('a plain web page is handed to the system unchanged', (
      tester,
    ) async {
      final opened = <Uri>[];
      await pumpPane(
        tester,
        content: webPage,
        resolvedPath: 'https://thinktac.com/activities',
        launcher: (uri) async {
          opened.add(uri);
          return true;
        },
      );

      expect(find.text('Opens in your browser'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(opened.single.toString(), 'https://thinktac.com/activities');
    });

    testWidgets('a refusal to open is reported, not swallowed', (tester) async {
      await pumpPane(
        tester,
        content: webPage,
        resolvedPath: 'https://thinktac.com/activities',
        launcher: (uri) async => false,
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Could not open this'), findsOneWidget);
    });

    testWidgets('a PDF whose bytes never arrive offers the browser instead', (
      tester,
    ) async {
      // A Storage path is not a URL, so the fallback still has to exchange it
      // for one carrying the token before anything can open it.
      final source = _StubSource();
      final opened = <Uri>[];
      await pumpPane(
        tester,
        content: guide,
        resolvedPath: 'learningUnits/lu1/Sample.pdf',
        source: source,
        launcher: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await tester.pump();

      expect(find.textContaining('could not be downloaded'), findsOneWidget);
      await tester.tap(find.text('Open outside the app'));
      await tester.pumpAndSettle();

      expect(source.resolved, ['learningUnits/lu1/Sample.pdf']);
      expect(opened.single.toString(), 'https://storage.example/Sample.pdf');
    });

    testWidgets('a failure resolving the path is reported too', (tester) async {
      await pumpPane(
        tester,
        content: guide,
        resolvedPath: 'learningUnits/lu1/Sample.pdf',
        source: _ThrowingSource(),
        launcher: (uri) async => true,
      );
      await tester.pump();

      await tester.tap(find.text('Open outside the app'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Could not open this'), findsOneWidget);
    });
  });
}

class _ThrowingSource implements StorageFileSource {
  @override
  Future<File?> cached(String storagePath) async => null;

  @override
  Future<String> resolve(String storagePath) async =>
      throw StateError('object-not-found');

  @override
  Future<File> download(String storagePath) async =>
      throw StateError('object-not-found');

  @override
  String cacheKey(String storagePath) => storagePath;
}
