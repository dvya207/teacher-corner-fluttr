import 'classroom_list_item.dart';

/// The classroom list's search.
///
/// A pure function on purpose: it is the phase's acceptance criterion, and a
/// filter that can only be exercised by typing into a running app is a filter
/// nobody re-checks after changing it.
class ClassroomSearch {
  ClassroomSearch._();

  /// Matches a classroom on its name, its INSTITUTION, its grade/section and
  /// its programmes.
  ///
  /// Institution is the point. Teachers search by school far more often than by
  /// class name, so typing "oak" has to find "7 A" at Test School Oak even
  /// though the classroom's own name contains no "oak" anywhere.
  ///
  /// Multi-token queries are AND, not substring: "oak 7" means both, so a
  /// teacher can narrow a long list by typing a school and then a grade,
  /// without having to guess the order the fields happen to be concatenated in.
  static List<ClassroomListItem> filter(
    List<ClassroomListItem> classrooms,
    String query,
  ) {
    final tokens = query.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((t) => t.isEmpty);
    if (tokens.isEmpty) return List.unmodifiable(classrooms);

    return List.unmodifiable(classrooms.where((classroom) {
      final haystack = _haystack(classroom);
      return tokens.every(haystack.contains);
    }));
  }

  static String _haystack(ClassroomListItem classroom) {
    return [
      classroom.displayName,
      classroom.institutionName,
      classroom.gradeSectionLabel,
      ...classroom.programmeLabels,
    ].whereType<String>().join(' ').toLowerCase();
  }
}
