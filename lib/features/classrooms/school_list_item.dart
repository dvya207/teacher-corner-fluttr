import 'classroom_list_item.dart';

/// One row of the dashboard's "My Schools" section: a school, and how much of
/// this teacher's work sits inside it.
///
/// DERIVED, NOT READ. There is no schools collection this app can query, and no
/// `institutionId` on either the teacher's denormalised classroom entry or the
/// authoritative `Classrooms/{id}` document, only `institutionName`. So a
/// school exists here exactly insofar as classrooms name it, and the section is
/// a regrouping of rows the dashboard has already loaded rather than a read of
/// its own. It therefore costs nothing and cannot fail on its own.
///
/// THE COST OF GROUPING BY NAME, stated plainly because it will eventually
/// bite: two genuinely different schools that share a name merge into one row,
/// and one school spelled two ways splits into two. Neither is repairable from
/// this side without an id on the classroom documents.
class SchoolListItem {
  const SchoolListItem({
    required this.name,
    required this.classroomCount,
    required this.programmeCount,
  });

  /// The school's name, in the first spelling the classrooms gave it.
  final String name;

  final int classroomCount;

  /// Distinct programmes across this school's classrooms, counted by id for the
  /// reason [ClassroomListItem.distinctProgrammeCount] gives: a name is not an
  /// identity, so counting names would merge two real programmes into one.
  final int programmeCount;

  /// Groups [classrooms] into schools, in the order the schools first appear.
  ///
  /// FIRST-APPEARANCE ORDER, not alphabetical, so this section reads in the same
  /// order as the classrooms above it and a teacher can follow one into the
  /// other rather than re-finding their place.
  ///
  /// CASE-INSENSITIVE KEY, DISPLAYING THE FIRST SPELLING SEEN. Live data holds
  /// the same school as "Test School Oak" in one place and "test school oak" in
  /// another. Two schools differing only in case is not a real thing, so merging
  /// them is the safer of the two mistakes on offer.
  ///
  /// A classroom naming no school is left out entirely rather than collected
  /// under a heading like "Unknown". The section answers "which schools do I
  /// teach at", and a row that names no school is not an answer to it.
  static List<SchoolListItem> groupFrom(List<ClassroomListItem> classrooms) {
    final order = <String>[];
    final names = <String, String>{};
    final classroomCounts = <String, int>{};
    final programmeIds = <String, Set<String>>{};
    final programmeFallback = <String, int>{};

    for (final classroom in classrooms) {
      final name = classroom.institutionName?.trim();
      if (name == null || name.isEmpty) continue;
      final key = name.toLowerCase();

      if (!names.containsKey(key)) {
        order.add(key);
        names[key] = name;
        classroomCounts[key] = 0;
        programmeIds[key] = <String>{};
        programmeFallback[key] = 0;
      }

      classroomCounts[key] = classroomCounts[key]! + 1;
      programmeIds[key]!.addAll(
        classroom.programmeIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty),
      );
      programmeFallback[key] =
          programmeFallback[key]! + classroom.distinctProgrammeCount;
    }

    return [
      for (final key in order)
        SchoolListItem(
          name: names[key]!,
          classroomCount: classroomCounts[key]!,
          // The label-derived fallback applies only when NO ids came through
          // for this school at all, so a school whose classrooms plainly run
          // programmes never reports zero. Where ids exist they win, because
          // summing per-classroom counts would double-count one programme
          // shared by two classrooms at the same school.
          programmeCount: programmeIds[key]!.isEmpty
              ? programmeFallback[key]!
              : programmeIds[key]!.length,
        ),
    ];
  }
}
