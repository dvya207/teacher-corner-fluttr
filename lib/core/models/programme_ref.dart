import '../utils/keyed_entries.dart';
import '../utils/safe_parse.dart';

/// A programme as it appears nested inside a classroom, in either the
/// denormalised copy on `Teachers/{uid}` or the authoritative
/// `Classrooms/{id}`.
class ProgrammeRef {
  const ProgrammeRef({required this.programmeId, this.displayName});

  final String programmeId;
  final String? displayName;

  /// Never empty, so a card never renders a blank line: falls back to the id,
  /// which is at least identifiable, rather than to nothing.
  String get label {
    final name = displayName?.trim();
    return (name != null && name.isNotEmpty) ? name : programmeId;
  }

  /// Parses the `programmes` field, which is a map keyed by programme id on
  /// most documents and occasionally a list.
  ///
  /// SCHEMA.md: "The key IS the id; the nested programmeId field is a duplicate
  /// of it and is sometimes missing. Prefer the key." So the key wins, and the
  /// inner field is only consulted in list form where there is no key.
  static List<ProgrammeRef> listFrom(
    dynamic raw, {
    String? collection,
    String? docId,
  }) {
    final out = <ProgrammeRef>[];
    for (final entry in KeyedEntries.from(
      raw,
      collection: collection,
      docId: docId,
      field: 'programmes',
    )) {
      final id = entry.key ??
          SafeParse.asRefString(
            entry.value['programmeId'],
            collection: collection,
            docId: docId,
            field: 'programmes.programmeId',
          );
      // No id by either route means nothing can link to it or open it. Drop it
      // rather than carry an unreachable row.
      if (id == null || id.isEmpty) continue;
      out.add(ProgrammeRef(
        programmeId: id,
        displayName: SafeParse.asDisplayString(entry.value['displayName']),
      ));
    }
    return out;
  }
}
