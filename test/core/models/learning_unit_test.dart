import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/learning_unit.dart';

/// `LearningUnits/lu_magnetic_pen_stand` as seeded.
Map<String, dynamic> seededLearningUnit() => {
  'learningUnitDisplayName': 'Magnetic Pen Stand',
  'type': 'TACtivity',
  'shortDescription': 'Build a pen stand that holds itself up with magnets.',
  'longDescription':
      'Children build a pen stand from card and two magnets, then work out why '
      'it stays upright without glue.',
  'stepCount': 6,
  'subjectName': 'Science',
  'learningUnitPreviewImage': 'luImages/divya-teacher-corner/mps_200x200.png',
  'Maturity': 'gold',
  'resources': {'gold': 'lur_mps_gold'},
};

void main() {
  group('the seeded document', () {
    test('parses the fields the card shows', () {
      final lu = LearningUnit.fromMap('lu_mps', seededLearningUnit());

      expect(lu.label, 'Magnetic Pen Stand');
      expect(lu.type, 'TACtivity');
      expect(lu.stepCount, 6);
      expect(lu.subjectName, 'Science');
      // Field name on the document is capitalised.
      expect(lu.maturity, 'gold');
    });

    test('carries a preview PATH and its maturity resource', () {
      final lu = LearningUnit.fromMap('lu_mps', seededLearningUnit());

      expect(
        lu.previewImagePath,
        'luImages/divya-teacher-corner/mps_200x200.png',
      );
      // Emphatically a path, not a resolved URL.
      expect(lu.previewImagePath, isNot(startsWith('http')));
      expect(lu.resourceIdForMaturity, 'lur_mps_gold');
      expect(lu.longDescription, isNotNull);
    });

    test('a document without those fields still parses', () {
      // Older units predate them, and a missing preview must degrade to a
      // placeholder rather than a broken image or a crash.
      final lu = LearningUnit.fromMap('lu_old', {
        'learningUnitDisplayName': 'Older Unit',
      });

      expect(lu.previewImagePath, isNull);
      expect(lu.resources, isEmpty);
      expect(lu.resourceIdForMaturity, isNull);
      expect(lu.longDescription, isNull);
    });
  });

  group('the three names for one field', () {
    test('prefers learningUnitDisplayName', () {
      final lu = LearningUnit.fromMap('lu_x', {
        'learningUnitDisplayName': 'Preferred',
        'learningUnitName': 'Second',
        'name': 'Third',
      });
      expect(lu.label, 'Preferred');
    });

    test('falls back to learningUnitName', () {
      final lu = LearningUnit.fromMap('lu_x', {
        'learningUnitName': 'Second',
        'name': 'Third',
      });
      expect(lu.label, 'Second');
    });

    test('falls back to name', () {
      final lu = LearningUnit.fromMap('lu_x', {'name': 'Third'});
      expect(lu.label, 'Third');
    });

    test('falls back to the id, never to blank or "null"', () {
      final lu = LearningUnit.fromMap('lu_nameless', const {});
      expect(lu.label, 'lu_nameless');
      expect(lu.label, isNot(contains('null')));
    });
  });

  group('the preview image is a Storage path', () {
    test('is kept verbatim, so a cache can be keyed on it', () {
      // Keying a cache on the resolved download URL never hits: Firebase mints
      // a fresh access token into every getDownloadURL() result, so the same
      // file yields a different URL every call.
      final lu = LearningUnit.fromMap('lu_x', {
        'learningUnitPreviewImage': 'luImages/mps_200x200.png',
      });

      expect(lu.previewImagePath, 'luImages/mps_200x200.png');
      // Emphatically not a URL.
      expect(lu.previewImagePath, isNot(startsWith('http')));
    });

    test('a non-String path is rejected rather than coerced', () {
      // A path built from a number would point at a file that does not exist.
      final lu = LearningUnit.fromMap('lu_x', {'learningUnitPreviewImage': 42});
      expect(lu.previewImagePath, isNull);
    });
  });

  group('resources', () {
    test('maps the unit maturity to its resource document', () {
      final lu = LearningUnit.fromMap('lu_x', {
        'Maturity': 'gold',
        'resources': {'gold': 'lur_mps_gold', 'silver': 'lur_mps_silver'},
      });

      expect(lu.resourceIdForMaturity, 'lur_mps_gold');
    });

    test('a maturity with no matching resource returns null', () {
      final lu = LearningUnit.fromMap('lu_x', {
        'Maturity': 'bronze',
        'resources': {'gold': 'lur_mps_gold'},
      });
      expect(lu.resourceIdForMaturity, isNull);
    });

    test('a non-String resource id is dropped, not fabricated', () {
      final lu = LearningUnit.fromMap('lu_x', {
        'resources': {'gold': 7},
      });
      expect(lu.resources, isEmpty);
    });

    test('the resources map cannot be mutated by a caller', () {
      final lu = LearningUnit.fromMap('lu_x', {
        'resources': {'gold': 'lur_x'},
      });
      expect(() => lu.resources['silver'] = 'nope', throwsUnsupportedError);
    });
  });

  group('degrading', () {
    test('stepCount stored as a String still counts', () {
      expect(LearningUnit.fromMap('lu_x', {'stepCount': '6'}).stepCount, 6);
    });

    test('stepCount that is not a number degrades to null, not 0', () {
      // "0 steps" would be a claim about the activity; null is a claim about
      // the document.
      expect(
        LearningUnit.fromMap('lu_x', {'stepCount': 'six'}).stepCount,
        isNull,
      );
    });

    test('an empty document produces a usable object', () {
      final lu = LearningUnit.fromMap('lu_x', const {});
      expect(lu.learningUnitId, 'lu_x');
      expect(lu.stepCount, isNull);
      expect(lu.shortDescription, isNull);
    });
  });
}
