import 'package:cloud_firestore/cloud_firestore.dart';
import 'parse_diagnostics.dart';

/// Pure, never-throwing parsers for Firestore document values.
///
/// Firestore is schemaless: the same field can arrive as an int on one doc and
/// a String on another (the v1.2.0 crash was `grade` stored as a String hitting
/// `data['grade'] as int?`). These helpers replace every brittle `as`-cast in
/// the models and services with tolerant coercion that:
///   - never throws (a single malformed field can never blank a whole screen);
///   - is STRICT where correctness matters (IDs, ordered lists, epochs);
///   - is LOOSE only for human-facing display labels;
///   - reports each fallback to [ParseDiagnostics] so real-user coverage is
///     verifiable during the internal rollout.
///
/// Optional [collection]/[docId]/[field] arguments are pass-through context for
/// diagnostics only; they never affect the parsed result.
class SafeParse {
  SafeParse._();

  // --- Integers ---

  /// int passthrough. double/num accepted ONLY when finite and integral
  /// (8.0 -> 8; 8.9/NaN/Infinity -> null+log). String via [int.tryParse] only
  /// (rejects "8.9", scientific notation, "8th", non-numeric). bool -> null.
  /// Anything else -> null+log.
  static int? asIntOrNull(
    dynamic value, {
    String? collection,
    String? docId,
    String? field,
  }) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) {
      if (value.isFinite && value == value.truncateToDouble()) {
        return value.toInt();
      }
      _log(collection, docId, field, value, note: 'non-integral/non-finite double');
      return null;
    }
    if (value is num) {
      final d = value.toDouble();
      if (d.isFinite && d == d.truncateToDouble()) return value.toInt();
      _log(collection, docId, field, value, note: 'non-integral/non-finite num');
      return null;
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
      _log(collection, docId, field, value, note: 'String not an int');
      return null;
    }
    // bool and everything else.
    _log(collection, docId, field, value);
    return null;
  }

  /// Like [asIntOrNull] but returns [fallback] (and logs) when the value cannot
  /// be parsed. Use for fields the model treats as non-nullable with a default.
  static int asInt(
    dynamic value, {
    required int fallback,
    String? collection,
    String? docId,
    String? field,
  }) {
    final parsed = asIntOrNull(
      value,
      collection: collection,
      docId: docId,
      field: field,
    );
    return parsed ?? fallback;
  }

  // --- Doubles ---

  /// num -> toDouble IF finite. String via [double.tryParse] IF finite.
  /// NaN/Infinity (numeric or "Infinity"/"NaN") -> null+log. else null.
  static double? asDoubleOrNull(
    dynamic value, {
    String? collection,
    String? docId,
    String? field,
  }) {
    if (value == null) return null;
    if (value is double) {
      if (value.isFinite) return value;
      _log(collection, docId, field, value, note: 'non-finite double');
      return null;
    }
    if (value is num) {
      final d = value.toDouble();
      if (d.isFinite) return d;
      _log(collection, docId, field, value, note: 'non-finite num');
      return null;
    }
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null && parsed.isFinite) return parsed;
      _log(collection, docId, field, value, note: 'String not a finite double');
      return null;
    }
    _log(collection, docId, field, value);
    return null;
  }

  // --- Strings ---

  /// LOOSE stringifier for human-facing display labels ONLY (names, titles,
  /// descriptions). String -> itself; int/double/bool -> toString(); null ->
  /// null. Never use for IDs/paths/refs (use [asRefString]).
  static String? asDisplayString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int || value is double || value is bool) {
      return value.toString();
    }
    // Maps/Lists/etc. are not meaningful labels.
    return null;
  }

  /// STRICT string for IDs, document paths, doc refs and enum keys. ONLY a real
  /// String passes; numbers/bools/etc. -> null+log (never fabricate an ID from
  /// a number, which would silently point at the wrong document).
  static String? asRefString(
    dynamic value, {
    String? collection,
    String? docId,
    String? field,
  }) {
    if (value == null) return null;
    if (value is String) return value;
    _log(collection, docId, field, value, note: 'ref/id field was not a String');
    return null;
  }

  // --- Booleans ---

  /// bool passthrough; tolerant of "true"/"false" (case-insensitive) and 1/0.
  /// Anything ambiguous -> [fallback].
  static bool asBool(
    dynamic value, {
    bool fallback = false,
    String? collection,
    String? docId,
    String? field,
  }) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
      _log(collection, docId, field, value, note: 'String not a bool');
      return fallback;
    }
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
      _log(collection, docId, field, value, note: 'num not 0/1');
      return fallback;
    }
    if (value != null) _log(collection, docId, field, value);
    return fallback;
  }

  // --- Lists ---

  /// Policy for an element that the per-element parser rejects.
  ///   drop    : skip it (default for display lists);
  ///   keepDefault : substitute the supplied default (rare);
  ///   fail    : abort the whole list -> returns null (for ordered/parallel/
  ///             required lists where a dropped element corrupts alignment).

  /// Accepts a List with mixed elements; coerces each via [asDisplayString].
  /// [policy] decides what to do with un-stringifiable elements. Returns null
  /// only under [ListPolicy.fail] when an element is rejected.
  static List<String>? asStringList(
    dynamic value, {
    ListPolicy policy = ListPolicy.drop,
    String defaultValue = '',
    String? collection,
    String? docId,
    String? field,
  }) {
    if (value == null) return const [];
    if (value is! List) {
      _log(collection, docId, field, value, note: 'expected List');
      return const [];
    }
    final out = <String>[];
    var dropped = 0;
    for (final e in value) {
      final parsed = asDisplayString(e);
      if (parsed != null) {
        out.add(parsed);
        continue;
      }
      switch (policy) {
        case ListPolicy.fail:
          _log(collection, docId, field, e,
              note: 'unparseable element in required list; failing whole list');
          return null;
        case ListPolicy.keepDefault:
          out.add(defaultValue);
          dropped++;
        case ListPolicy.drop:
          dropped++;
      }
    }
    if (dropped > 0) {
      _log(collection, docId, field, value,
          note: 'dropped $dropped of ${value.length} string elements');
    }
    return out;
  }

  /// Accepts a List with mixed elements; coerces each via [asIntOrNull].
  /// Same [policy] semantics as [asStringList].
  static List<int>? asIntList(
    dynamic value, {
    ListPolicy policy = ListPolicy.drop,
    int defaultValue = 0,
    String? collection,
    String? docId,
    String? field,
  }) {
    if (value == null) return const [];
    if (value is! List) {
      _log(collection, docId, field, value, note: 'expected List');
      return const [];
    }
    final out = <int>[];
    var dropped = 0;
    for (final e in value) {
      final parsed = asIntOrNull(e);
      if (parsed != null) {
        out.add(parsed);
        continue;
      }
      switch (policy) {
        case ListPolicy.fail:
          _log(collection, docId, field, e,
              note: 'unparseable element in required int list; failing list');
          return null;
        case ListPolicy.keepDefault:
          out.add(defaultValue);
          dropped++;
        case ListPolicy.drop:
          dropped++;
      }
    }
    if (dropped > 0) {
      _log(collection, docId, field, value,
          note: 'dropped $dropped of ${value.length} int elements');
    }
    return out;
  }

  // --- Maps ---

  /// Coerces a Map to a `Map<String, dynamic>`, stringifying non-String keys.
  /// On a `1` vs `"1"` collision it logs and keeps the last writer. Returns an
  /// empty map for null / non-Map input (logged for the non-Map case).
  static Map<String, dynamic> asStringKeyedMap(
    dynamic value, {
    String? collection,
    String? docId,
    String? field,
  }) {
    if (value == null) return <String, dynamic>{};
    if (value is! Map) {
      _log(collection, docId, field, value, note: 'expected Map');
      return <String, dynamic>{};
    }
    // Fast path: keys are already statically String.
    if (value is Map<String, dynamic>) {
      return value;
    }
    final out = <String, dynamic>{};
    value.forEach((k, v) {
      final key = k is String ? k : k.toString();
      if (out.containsKey(key)) {
        _log(collection, docId, field, k,
            note: 'colliding map key "$key"; last write wins');
      }
      out[key] = v;
    });
    return out;
  }

  // --- Dates ---

  /// Tolerant date parsing, normalized to a UTC [DateTime] at the boundary
  /// (store/compare in UTC; widgets render local via .toLocal()).
  ///   Timestamp -> toDate().toUtc();
  ///   DateTime  -> .toUtc();
  ///   int       -> epoch with EXPLICIT [unit] (ms vs seconds) + sanity range
  ///               (year 2000..2100); out of range -> null+log;
  ///   String    -> DateTime.tryParse then .toUtc();
  ///   else      -> null.
  static DateTime? asDate(
    dynamic value, {
    EpochUnit unit = EpochUnit.milliseconds,
    String? collection,
    String? docId,
    String? field,
  }) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is int) {
      final ms = unit == EpochUnit.seconds ? value * 1000 : value;
      final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      if (dt.year < 2000 || dt.year > 2100) {
        _log(collection, docId, field, value,
            note: 'epoch out of sane range (unit=$unit -> ${dt.toIso8601String()})');
        return null;
      }
      return dt;
    }
    if (value is double) {
      // Coerce a finite integral double epoch; otherwise reject.
      final asInt = asIntOrNull(value);
      if (asInt == null) {
        _log(collection, docId, field, value, note: 'non-integral epoch double');
        return null;
      }
      return asDate(asInt,
          unit: unit, collection: collection, docId: docId, field: field);
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed.toUtc();
      _log(collection, docId, field, value, note: 'String not a parseable date');
      return null;
    }
    _log(collection, docId, field, value);
    return null;
  }

  // --- Internal ---

  static void _log(
    String? collection,
    String? docId,
    String? field,
    dynamic observed, {
    String? note,
  }) {
    ParseDiagnostics.record(
      collection: collection,
      docId: docId,
      field: field ?? '<unknown>',
      observedType: observed?.runtimeType.toString() ?? 'Null',
      note: note,
    );
  }
}

/// How an out-of-shape list element is handled.
enum ListPolicy { drop, keepDefault, fail }

/// Whether an integer epoch is seconds or milliseconds since 1970.
enum EpochUnit { seconds, milliseconds }
