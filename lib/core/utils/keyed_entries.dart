import 'safe_parse.dart';

/// One child object pulled out of a "collection of children" field, with the
/// map key it was stored under when there was one.
typedef KeyedEntry = ({String? key, Map<String, dynamic> value});

/// Firestore documents in this project store a collection of child objects two
/// different ways, and SCHEMA.md says to tolerate both:
///
///   * a MAP keyed by the child's id (`classrooms`, `programmes`), where the
///     key IS the id and the id field inside is a sometimes-missing duplicate;
///   * a LIST of objects that each carry their own id (`workflowIds` on one
///     classroom, a map on another).
///
/// Same meaning, written by three different systems over several years. This
/// flattens either shape into one ordered list so callers hold the tolerance in
/// one place instead of at every call site.
class KeyedEntries {
  KeyedEntries._();

  /// Map keys are sorted so the UI order is stable across reads: Firestore does
  /// not promise map key order, and an unordered list of classrooms that
  /// reshuffles between launches looks like a bug to a teacher.
  static List<KeyedEntry> from(
    dynamic raw, {
    String? collection,
    String? docId,
    String? field,
  }) {
    if (raw == null) return const [];

    if (raw is Map) {
      final map = SafeParse.asStringKeyedMap(
        raw,
        collection: collection,
        docId: docId,
        field: field,
      );
      final keys = map.keys.toList()..sort(_naturalCompare);
      final out = <KeyedEntry>[];
      for (final key in keys) {
        final value = map[key];
        if (value is! Map) {
          // A key whose value is not an object cannot describe a child. Log and
          // drop the one entry rather than failing the whole collection.
          SafeParse.asStringKeyedMap(
            value,
            collection: collection,
            docId: docId,
            field: '$field[$key]',
          );
          continue;
        }
        out.add((
          key: key,
          value: SafeParse.asStringKeyedMap(
            value,
            collection: collection,
            docId: docId,
            field: '$field[$key]',
          ),
        ));
      }
      return out;
    }

    if (raw is List) {
      final out = <KeyedEntry>[];
      for (var i = 0; i < raw.length; i++) {
        final value = raw[i];
        if (value is! Map) {
          SafeParse.asStringKeyedMap(
            value,
            collection: collection,
            docId: docId,
            field: '$field[$i]',
          );
          continue;
        }
        out.add((
          // No key in list form, so the id has to come from inside the object.
          key: null,
          value: SafeParse.asStringKeyedMap(
            value,
            collection: collection,
            docId: docId,
            field: '$field[$i]',
          ),
        ));
      }
      return out;
    }

    // Neither a Map nor a List: log the shape and degrade to empty.
    SafeParse.asStringKeyedMap(
      raw,
      collection: collection,
      docId: docId,
      field: field,
    );
    return const [];
  }

  /// Compares "10" after "9" rather than before it, so numeric-ish keys such as
  /// the map form of `workflowIds` ("0", "1", … "10") keep their real order.
  static int _naturalCompare(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.compareTo(b);
  }
}
