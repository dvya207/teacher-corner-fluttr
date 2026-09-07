import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/learning_unit_resources.dart';

/// `learningUnitResources/rfasd9I0Pi1UXKjNHMOi`, shaped as teacher-corner-dev
/// actually stores it: five category groups, most leaves empty, a couple of
/// leaves keyed by board rather than holding the path directly.
Map<String, dynamic> liveDocument() => {
  'learningUnitDocId': '1mn1Tx0w1jJ5Z1496BW4',
  'resources': {
    '3S': {
      'conceptPostTestQuizPdf': {'universalGradeBoardResourcePath': ''},
      'quizzesDev': {'universalGradeBoardResourcePath': ''},
    },
    'graphics': {'headlineImage': '', 'qrCode': ''},
    'video': {
      'tacVideoDriveUrl': 'https://www.youtube.com/watch?v=Pkh8UtuejGw',
      'tacVideoMp4': 'learningUnits/1mn1Tx0w1jJ5Z1496BW4/Treat you better.mp4',
      'tacVideoProject': '',
    },
    'socialMedia': {
      'tacVideoReelMp4': 'learningUnits/1mn1Tx0w1jJ5Z1496BW4/sample.mp4',
      'tacVideoReelProject': '',
    },
    'tacDev': {
      'devGuidePdf': 'learningUnits/1mn1Tx0w1jJ5Z1496BW4/Sample.pdf',
      'materialList': {'CBSE': 'KrHYoe8bQJJyRbKKyuhH'},
      'inference': '',
    },
  },
};

void main() {
  group('resolving a step content to its upload', () {
    late LearningUnitResources resources;

    setUp(() {
      resources = LearningUnitResources.fromMap('doc1', liveDocument());
    });

    test('finds the YouTube link a video content points at', () {
      // The exact pairing the Swimming workflow uses: its first step's
      // "Tactivity" content is category=video, sub=tacVideoDriveUrl.
      expect(
        resources.pathFor(category: 'video', subCategory: 'tacVideoDriveUrl'),
        'https://www.youtube.com/watch?v=Pkh8UtuejGw',
      );
    });

    test('finds a Storage path just the same', () {
      expect(
        resources.pathFor(
          category: 'socialMedia',
          subCategory: 'tacVideoReelMp4',
        ),
        'learningUnits/1mn1Tx0w1jJ5Z1496BW4/sample.mp4',
      );
      expect(
        resources.pathFor(category: 'tacDev', subCategory: 'devGuidePdf'),
        'learningUnits/1mn1Tx0w1jJ5Z1496BW4/Sample.pdf',
      );
    });

    test('does NOT take a board key as a path, because it is a document id', () {
      // THIS TEST ASSERTED THE OPPOSITE AND THE OPPOSITE WAS THE BUG. It read
      // "this app does not know the teacher's board, and a guide uploaded only
      // for CBSE is still the guide for this activity", which is true of a
      // PATH and false of what is actually stored there. A board key on a
      // grade-dependent slot holds a `boardGradeResources` DOCUMENT ID:
      //
      //     tacDev.materialList = { CBSE: 'KrHYoe8bQJJyRbKKyuhH' }
      //
      // Returned as a path, that reached Storage as an object-not-found, and
      // the Pre-Test and Material List tabs told teachers nothing was uploaded
      // when the files were one document further along. The app does know the
      // board now: it comes from the classroom, along with the grade.
      expect(
        resources.pathFor(category: 'tacDev', subCategory: 'materialList'),
        isNull,
      );

      // The id is reachable, as an id, for the read that follows it.
      expect(
        resources.boardDocIdFor(
          category: 'tacDev',
          subCategory: 'materialList',
          board: 'CBSE',
        ),
        'KrHYoe8bQJJyRbKKyuhH',
      );
    });

    test('an empty leaf reads as nothing uploaded, not as an empty path', () {
      // The distinction the content pane depends on: null means "not uploaded
      // yet", and an empty string would send Storage a request for "".
      expect(
        resources.pathFor(category: 'video', subCategory: 'tacVideoProject'),
        isNull,
      );
      expect(
        resources.pathFor(category: 'graphics', subCategory: 'headlineImage'),
        isNull,
      );
    });

    test('an empty board map is also nothing uploaded', () {
      expect(
        resources.pathFor(category: '3S', subCategory: 'quizzesDev'),
        isNull,
      );
    });

    test('an unknown category or subCategory is null, not a crash', () {
      expect(
        resources.pathFor(category: 'nope', subCategory: 'devGuidePdf'),
        isNull,
      );
      expect(resources.pathFor(category: 'tacDev', subCategory: 'nope'), isNull);
    });

    test('a missing or blank pointer resolves to nothing', () {
      // A content with no subCategory cannot name a resource, and guessing one
      // from the category alone would show a teacher the wrong file.
      expect(resources.pathFor(category: 'video', subCategory: null), isNull);
      expect(resources.pathFor(category: 'video', subCategory: '  '), isNull);
      expect(resources.pathFor(category: null, subCategory: 'x'), isNull);
    });
  });

  group('parsing', () {
    test('drops categories whose leaves are all empty', () {
      // Keeps the map to what is actually there, so a present key means a
      // present file.
      final r = LearningUnitResources.fromMap('doc1', liveDocument());
      expect(r.byCategory.containsKey('graphics'), isFalse);
      expect(r.byCategory.keys, containsAll(['video', 'socialMedia', 'tacDev']));
    });

    test('the universal path wins over a board-specific one', () {
      final r = LearningUnitResources.fromMap('doc1', {
        'resources': {
          'tacDev': {
            'devGuidePdf': {
              'CBSE': 'cbse/guide.pdf',
              'universalGradeBoardResourcePath': 'shared/guide.pdf',
            },
          },
        },
      });
      expect(
        r.pathFor(category: 'tacDev', subCategory: 'devGuidePdf'),
        'shared/guide.pdf',
      );
    });

    test('a document with no resources field is empty, not an error', () {
      final r = LearningUnitResources.fromMap('doc1', {});
      expect(r.isEmpty, isTrue);
      expect(r.pathFor(category: 'video', subCategory: 'x'), isNull);
    });

    test('a resources field of the wrong type is empty too', () {
      final r = LearningUnitResources.fromMap('doc1', {'resources': 'nope'});
      expect(r.isEmpty, isTrue);
    });
  });
}
