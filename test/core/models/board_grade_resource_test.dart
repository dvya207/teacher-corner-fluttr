import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/board_grade_resource.dart';
import 'package:tc_starter/core/models/learning_unit_resources.dart';
import 'package:tc_starter/core/models/resource_kind.dart';

/// The three-document chain a grade-dependent slot has to be followed through,
/// and the reason the Pre-Test tab was empty.
///
/// Every value here is copied out of teacher-corner-dev: the resource document
/// `1eXvhUXV7stAgLMV8BA0` for Sterling Point, and the two
/// `boardGradeResources` documents it points at.

/// Sterling Point's Gold resource document, as stored.
LearningUnitResources sterlingPointResources() =>
    LearningUnitResources.fromMap('1eXvhUXV7stAgLMV8BA0', {
      'resources': {
        // A PLAIN slot: the value is the file.
        'tacDev': {'devGuidePdf': 'learningUnits/2awVLuyYaxFqMFuVp3Ny/Sample.pdf'},
        // GRADE-DEPENDENT slots: the board key is a document id, and the
        // universal copy is empty on every one of them in this database.
        '3S': {
          'conceptPreTestQuizPdf': {
            'universalGradeBoardResourcePath': '',
            'CBSE': 's9qKMMiIrTMVaay3Kn14',
          },
          'conceptPostTestQuizPdf': {
            'universalGradeBoardResourcePath': '',
            'CBSE': 'X2GPbu1KeM9arUdINweL',
          },
        },
      },
    });

/// The board copies, keyed by document id as the fetch returns them.
Map<String, BoardGradeResource> sterlingPointBoardGrades() => {
  's9qKMMiIrTMVaay3Kn14': BoardGradeResource.fromMap('s9qKMMiIrTMVaay3Kn14', {
    'learningUnitDocId': '2awVLuyYaxFqMFuVp3Ny',
    'category': '3S',
    'subCategory': 'conceptPreTestQuizPdf',
    'board': 'CBSE',
    'maturity': 'Gold',
    'resources': {
      'grade_01':
          'learningUnits/2awVLuyYaxFqMFuVp3Ny/GradeDependentResources/Sample.pdf',
    },
  }),
  'X2GPbu1KeM9arUdINweL': BoardGradeResource.fromMap('X2GPbu1KeM9arUdINweL', {
    'learningUnitDocId': '2awVLuyYaxFqMFuVp3Ny',
    'category': '3S',
    'subCategory': 'conceptPostTestQuizPdf',
    'board': 'CBSE',
    'maturity': 'Gold',
    'resources': {
      'grade_01': 'learningUnits/2awVLuyYaxFqMFuVp3Ny/'
          'GradeDependentResources/impeccable-skill-guide.pdf',
    },
  }),
};

void main() {
  group('the two leaf shapes are kept apart', () {
    test('a plain slot answers with its own path', () {
      expect(
        sterlingPointResources().pathFor(
          category: 'tacDev',
          subCategory: 'devGuidePdf',
        ),
        'learningUnits/2awVLuyYaxFqMFuVp3Ny/Sample.pdf',
      );
    });

    test('a grade-dependent slot NEVER answers with its board document id', () {
      // THE BUG. The old code took "universal, else the first non-empty value",
      // so this returned 's9qKMMiIrTMVaay3Kn14'. The pane was handed a document
      // id where it expected a file and told the teacher there was nothing
      // there, while the PDF sat one document further along the chain.
      final path = sterlingPointResources().pathFor(
        category: '3S',
        subCategory: 'conceptPreTestQuizPdf',
      );

      expect(path, isNull);
      expect(path, isNot('s9qKMMiIrTMVaay3Kn14'));
    });

    test('and the slot is marked as needing the extra reads', () {
      final resources = sterlingPointResources();

      expect(resources.hasGradeDependentSlot, isTrue);
      expect(
        resources.slotFor(category: '3S', subCategory: 'conceptPreTestQuizPdf')!
            .isGradeDependent,
        isTrue,
      );
      expect(
        resources.slotFor(category: 'tacDev', subCategory: 'devGuidePdf')!
            .isGradeDependent,
        isFalse,
      );
    });

    test('a unit with only plain slots pays for no extra reads', () {
      final plain = LearningUnitResources.fromMap('r', {
        'resources': {
          'video': {'tacVideoMp4': 'learningUnits/lu1/clip.mp4'},
        },
      });

      expect(plain.hasGradeDependentSlot, isFalse);
    });
  });

  group('following the chain to the file', () {
    test('the board key yields the document id to read next', () {
      expect(
        sterlingPointResources().boardDocIdFor(
          category: '3S',
          subCategory: 'conceptPreTestQuizPdf',
          board: 'CBSE',
        ),
        's9qKMMiIrTMVaay3Kn14',
      );
    });

    test('a board with no copy yields nothing', () {
      expect(
        sterlingPointResources().boardDocIdFor(
          category: '3S',
          subCategory: 'conceptPreTestQuizPdf',
          board: 'ICSE',
        ),
        isNull,
      );
      // Board unknown is the same answer, not a crash.
      expect(
        sterlingPointResources().boardDocIdFor(
          category: '3S',
          subCategory: 'conceptPreTestQuizPdf',
          board: null,
        ),
        isNull,
      );
    });

    test('and that document yields the PDF, for the grade it was uploaded for', () {
      final path = sterlingPointBoardGrades()['s9qKMMiIrTMVaay3Kn14']!
          .pathForGrade(BoardGradeResource.gradeKey(1));

      expect(
        path,
        'learningUnits/2awVLuyYaxFqMFuVp3Ny/GradeDependentResources/Sample.pdf',
      );
      // And it reaches the PDF viewer rather than a card saying it is not a file.
      expect(ResolvedResource.of(path)!.kind, ResourceKind.pdf);
    });

    test('a grade with no copy yields nothing, NOT another grade\'s file', () {
      // THE STATE THIS DATA IS ACTUALLY IN. Both Sterling Point PDFs were
      // uploaded for grade_01, and the classroom running the workflow is
      // grade 4. A teacher must not be handed the grade-1 paper to run a
      // grade-4 lesson from, so this stays empty and says so.
      expect(
        sterlingPointBoardGrades()['s9qKMMiIrTMVaay3Kn14']!
            .pathForGrade(BoardGradeResource.gradeKey(4)),
        isNull,
      );
    });
  });

  group('gradeKey matches the format the documents are written with', () {
    test('a number is zero-padded to two digits', () {
      // grade_4 would find nothing: the key on the document is grade_04.
      expect(BoardGradeResource.gradeKey(4), 'grade_04');
      expect(BoardGradeResource.gradeKey('4'), 'grade_04');
      expect(BoardGradeResource.gradeKey(12), 'grade_12');
      expect(BoardGradeResource.gradeKey(1), 'grade_01');
    });

    test('pre-primary years have their own shape', () {
      // Live classroom data holds 'Pre-primary 2' as a grade.
      expect(
        BoardGradeResource.gradeKey('Pre-primary 2'),
        'grade_preprimary_2',
      );
      expect(BoardGradeResource.gradeKey('pre primary 1'), 'grade_preprimary_1');
    });

    test('anything else has no key, which means no board copy', () {
      // 'ET' is in this data too. No key is a normal state, not an error.
      expect(BoardGradeResource.gradeKey('ET'), '');
      expect(BoardGradeResource.gradeKey(null), '');
      expect(BoardGradeResource.gradeKey(''), '');
    });
  });
}
