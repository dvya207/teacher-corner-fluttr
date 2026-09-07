import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/features/classrooms/classroom_list_item.dart';
import 'package:tc_starter/features/classrooms/school_list_item.dart';

ClassroomListItem classroom({
  String id = 'cls',
  String name = 'A class',
  String? school,
  List<String> programmeIds = const [],
  List<String> programmeLabels = const [],
}) => ClassroomListItem(
  classroomId: id,
  displayName: name,
  institutionName: school,
  programmeIds: programmeIds,
  programmeLabels: programmeLabels,
);

void main() {
  group('grouping classrooms into schools', () {
    test('one row per school, counting its classrooms', () {
      final schools = SchoolListItem.groupFrom([
        classroom(id: 'a', school: 'Test School Oak'),
        classroom(id: 'b', school: 'Test School Oak'),
        classroom(id: 'c', school: 'Airaa Academy'),
      ]);

      expect(schools.map((s) => s.name), ['Test School Oak', 'Airaa Academy']);
      expect(schools.map((s) => s.classroomCount), [2, 1]);
    });

    test('keeps the order the schools first appear in, not alphabetical', () {
      // The section sits directly under the classrooms it summarises, so a
      // teacher reads down one and into the other. Sorting would break that.
      final schools = SchoolListItem.groupFrom([
        classroom(id: 'a', school: 'Zebra School'),
        classroom(id: 'b', school: 'Airaa Academy'),
        classroom(id: 'c', school: 'Zebra School'),
      ]);

      expect(schools.map((s) => s.name), ['Zebra School', 'Airaa Academy']);
    });

    test('counts a shared programme once for the school, not once per class', () {
      // The whole reason the count is a set of ids rather than a sum. A school
      // running one programme across three classes runs ONE programme.
      final schools = SchoolListItem.groupFrom([
        classroom(id: 'a', school: 'Oak', programmeIds: ['prg_tip']),
        classroom(id: 'b', school: 'Oak', programmeIds: ['prg_tip']),
        classroom(id: 'c', school: 'Oak', programmeIds: ['prg_tip', 'prg_stem']),
      ]);

      expect(schools.single.classroomCount, 3);
      expect(schools.single.programmeCount, 2);
    });

    test('counts by id, so two programmes sharing a name stay two', () {
      final schools = SchoolListItem.groupFrom([
        classroom(
          id: 'a',
          school: 'Oak',
          programmeIds: ['prg_one', 'prg_two'],
          programmeLabels: ['Science 2026', 'Science 2026'],
        ),
      ]);

      expect(schools.single.programmeCount, 2);
    });

    test('ignores blank ids rather than counting them as a programme', () {
      final schools = SchoolListItem.groupFrom([
        classroom(id: 'a', school: 'Oak', programmeIds: ['prg_one', '', '  ']),
      ]);

      expect(schools.single.programmeCount, 1);
    });

    test('falls back to the labels when a school produced no ids at all', () {
      // A classroom whose programme ids failed to parse still plainly runs
      // programmes, and reporting zero would be a claim rather than a gap.
      final schools = SchoolListItem.groupFrom([
        classroom(id: 'a', school: 'Oak', programmeLabels: ['TIP 2026']),
      ]);

      expect(schools.single.programmeCount, 1);
    });

    test('ids win over labels, so a shared programme is not double counted', () {
      // Both classrooms carry the label, but they are the same programme. The
      // label sum would say two; the ids say one, and the ids are right.
      final schools = SchoolListItem.groupFrom([
        classroom(
          id: 'a',
          school: 'Oak',
          programmeIds: ['prg_tip'],
          programmeLabels: ['TIP 2026'],
        ),
        classroom(
          id: 'b',
          school: 'Oak',
          programmeIds: ['prg_tip'],
          programmeLabels: ['TIP 2026'],
        ),
      ]);

      expect(schools.single.programmeCount, 1);
    });
  });

  group('the name is the only key there is', () {
    test('merges spellings that differ only in case or padding', () {
      // Live data holds "Test School Oak" and "test school oak" for the same
      // school. Two schools differing only in case is not a real thing, so
      // merging is the safer of the two available mistakes.
      final schools = SchoolListItem.groupFrom([
        classroom(id: 'a', school: 'Test School Oak'),
        classroom(id: 'b', school: 'test school oak'),
        classroom(id: 'c', school: '  Test School Oak  '),
      ]);

      expect(schools, hasLength(1));
      expect(schools.single.classroomCount, 3);
    });

    test('displays the first spelling seen', () {
      final schools = SchoolListItem.groupFrom([
        classroom(id: 'a', school: 'test school oak'),
        classroom(id: 'b', school: 'Test School Oak'),
      ]);

      expect(schools.single.name, 'test school oak');
    });

    test('leaves out a classroom that names no school', () {
      // The section answers "which schools do I teach at". A row naming none is
      // not an answer to it, and an "Unknown" heading would be a school that
      // does not exist.
      final schools = SchoolListItem.groupFrom([
        classroom(id: 'a', school: 'Oak'),
        classroom(id: 'b'),
        classroom(id: 'c', school: ''),
        classroom(id: 'd', school: '   '),
      ]);

      expect(schools, hasLength(1));
      expect(schools.single.classroomCount, 1);
    });

    test('no classrooms means no schools, not an empty-named one', () {
      expect(SchoolListItem.groupFrom([]), isEmpty);
    });
  });
}
