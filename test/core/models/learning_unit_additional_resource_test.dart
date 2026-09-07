import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/learning_unit.dart';
import 'package:tc_starter/core/models/learning_unit_additional_resource.dart';

/// Shaped as teacher-corner-dev stores it, including the lowercase
/// `shortdescription` key and one deliberately unpublished entry.
List<Map<String, dynamic>> liveExtras() => [
  {
    'title': 'walk',
    'shortdescription': 'walk',
    'type': 'UPLOAD',
    'fileExtension': 'pdf',
    'resourcePath': 'learningUnits/lu1/Sample.pdf',
    'publish': true,
  },
  {
    'title': 'walkk',
    'shortdescription': 'walkk',
    'type': 'VIDEO',
    'fileExtension': 'video',
    'resourcePath': 'https://www.youtube.com/watch?v=lY2yjAdbvdQ',
    'publish': true,
  },
  {
    'title': 'run',
    'shortdescription': 'run',
    'type': 'UPLOAD',
    'fileExtension': 'pptx',
    'resourcePath': 'learningUnits/lu1/sample.pptx',
    'publish': false,
  },
];

void main() {
  group('parsing the extras a unit carries', () {
    test('reads every field, including the lowercase description key', () {
      final list = LearningUnitAdditionalResource.listFrom(liveExtras());
      expect(list, hasLength(3));
      final first = list.first;
      expect(first.title, 'walk');
      expect(first.description, 'walk');
      expect(first.type, 'UPLOAD');
      expect(first.fileExtension, 'pdf');
      expect(first.resourcePath, 'learningUnits/lu1/Sample.pdf');
      expect(first.publish, isTrue);
    });

    test('drops an entry with nothing to open', () {
      // A title and no file would render a row that does nothing when tapped.
      final list = LearningUnitAdditionalResource.listFrom([
        {'title': 'empty', 'resourcePath': ''},
        {'title': 'none'},
      ]);
      expect(list, isEmpty);
    });

    test('a missing publish flag defaults to shown', () {
      // Hiding a teacher's own upload on an absent boolean is the worse of the
      // two mistakes available.
      final list = LearningUnitAdditionalResource.listFrom([
        {'title': 'x', 'resourcePath': 'p/x.pdf'},
      ]);
      expect(list.single.publish, isTrue);
    });

    test('anything that is not a list is no extras, not a crash', () {
      expect(LearningUnitAdditionalResource.listFrom(null), isEmpty);
      expect(LearningUnitAdditionalResource.listFrom('nope'), isEmpty);
    });
  });

  group('what a teacher is shown', () {
    test('an unpublished extra is left out', () {
      final unit = LearningUnit.fromMap('lu1', {
        'additionalResources': liveExtras(),
      });
      expect(unit.additionalResources, hasLength(3));
      expect(
        unit.publishedAdditionalResources.map((r) => r.title),
        ['walk', 'walkk'],
      );
    });

    test('a row always has something to name it', () {
      final list = LearningUnitAdditionalResource.listFrom([
        {'resourcePath': 'p/x.pdf', 'fileExtension': 'pdf'},
      ]);
      expect(list.single.label, 'PDF');
    });
  });

  group('matching a slot that asks for a kind', () {
    test('"PPT" matches a pptx file, on the prefix', () {
      final r = LearningUnitAdditionalResource.listFrom([
        {'resourcePath': 'p/x.pptx', 'fileExtension': 'pptx'},
      ]).single;
      expect(r.matchesType('PPT'), isTrue);
      expect(r.matchesType('pdf'), isFalse);
    });

    test('a VIDEO matches on its type as well as its extension', () {
      final r = LearningUnitAdditionalResource.listFrom([
        {'resourcePath': 'https://x', 'type': 'VIDEO', 'fileExtension': 'video'},
      ]).single;
      expect(r.matchesType('VIDEO'), isTrue);
      expect(r.matchesType('video'), isTrue);
    });

    test('a slot asking for nothing matches nothing', () {
      // It orders the list rather than filtering it, so "no preference" must
      // not silently mean "everything matches".
      final r = LearningUnitAdditionalResource.listFrom([
        {'resourcePath': 'p/x.pdf', 'fileExtension': 'pdf'},
      ]).single;
      expect(r.matchesType(null), isFalse);
      expect(r.matchesType('  '), isFalse);
    });
  });
}
