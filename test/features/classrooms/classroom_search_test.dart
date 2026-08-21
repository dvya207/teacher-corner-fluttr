import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/features/classrooms/classroom_list_item.dart';
import 'package:tc_starter/features/classrooms/classroom_search.dart';

ClassroomListItem item({
  required String id,
  required String name,
  String? institution,
  String? gradeSection,
  List<String> programmes = const [],
}) =>
    ClassroomListItem(
      classroomId: id,
      displayName: name,
      institutionName: institution,
      gradeSectionLabel: gradeSection,
      programmeLabels: programmes,
    );

/// The two seeded classrooms, as the list would assemble them.
final seeded = [
  item(
    id: 'cls_oak_7a',
    name: '7 A',
    institution: 'Test School Oak',
    gradeSection: 'Grade 7 · A',
    programmes: ['TIP 2026'],
  ),
  item(
    id: 'cls_oak_et',
    name: 'Oak ET Club',
    institution: 'Test School Oak',
    programmes: ['TIP 2026'],
  ),
];

void main() {
  group('the acceptance criterion', () {
    test('"oak" finds the classroom whose INSTITUTION is Test School Oak', () {
      // "7 A" contains no "oak" anywhere in its own name. Teachers search by
      // school far more often than by class name, so this has to match.
      final results = ClassroomSearch.filter(seeded, 'oak');

      expect(results.map((c) => c.classroomId),
          containsAll(['cls_oak_7a', 'cls_oak_et']));
    });

    test('a name-only filter would have missed it', () {
      // Guards against someone "simplifying" the filter back to name matching.
      final nameOnly = seeded
          .where((c) => c.displayName.toLowerCase().contains('oak'))
          .toList();

      expect(nameOnly.map((c) => c.classroomId), ['cls_oak_et']);
      expect(ClassroomSearch.filter(seeded, 'oak').length,
          greaterThan(nameOnly.length));
    });
  });

  group('what else is searchable', () {
    test('the classroom name', () {
      expect(ClassroomSearch.filter(seeded, '7 A').single.classroomId,
          'cls_oak_7a');
    });

    test('the grade label', () {
      expect(ClassroomSearch.filter(seeded, 'grade 7').single.classroomId,
          'cls_oak_7a');
    });

    test('the programme', () {
      expect(ClassroomSearch.filter(seeded, 'tip').length, 2);
    });

    test('case is ignored in both directions', () {
      expect(ClassroomSearch.filter(seeded, 'OAK').length, 2);
      expect(ClassroomSearch.filter(seeded, 'test school oak').length, 2);
    });
  });

  group('query handling', () {
    test('an empty query returns everything', () {
      expect(ClassroomSearch.filter(seeded, '').length, 2);
    });

    test('whitespace only returns everything, not nothing', () {
      // A teacher who taps the field and hits space must not see an empty list.
      expect(ClassroomSearch.filter(seeded, '   ').length, 2);
    });

    test('multiple tokens are AND, so "oak 7" narrows to one', () {
      final results = ClassroomSearch.filter(seeded, 'oak 7');
      expect(results.single.classroomId, 'cls_oak_7a');
    });

    test('token order does not matter', () {
      expect(ClassroomSearch.filter(seeded, '7 oak').single.classroomId,
          ClassroomSearch.filter(seeded, 'oak 7').single.classroomId);
    });

    test('extra internal whitespace is tolerated', () {
      expect(ClassroomSearch.filter(seeded, '  oak    7 ').single.classroomId,
          'cls_oak_7a');
    });

    test('no match returns empty rather than falling back to everything', () {
      expect(ClassroomSearch.filter(seeded, 'zzzz'), isEmpty);
    });
  });

  group('classrooms with missing fields', () {
    test('a null institution does not throw or match everything', () {
      final sparse = [item(id: 'cls_x', name: 'Nameless School Class')];

      expect(ClassroomSearch.filter(sparse, 'oak'), isEmpty);
      expect(ClassroomSearch.filter(sparse, 'nameless').length, 1);
    });

    test('the result list cannot be mutated by the caller', () {
      // The provider hands this straight to a ListView; an accidental in-place
      // sort would silently reorder the source of truth.
      expect(() => ClassroomSearch.filter(seeded, '').add(seeded.first),
          throwsUnsupportedError);
    });
  });
}
