import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Lightweight, dependency-free telemetry facade for parse fallbacks.
///
/// Release 1 deliberately does NOT pull in firebase_crashlytics /
/// firebase_analytics (no new heavy SDK in the urgent crash fix). Instead,
/// every never-throwing helper in [safe_parse] funnels its fallbacks here so
/// that, during the internal rollout, we can confirm real-user coverage by
/// reading the device logcat.
///
/// Each record captures only:
///   - collection (logical area, e.g. 'classrooms', supplied by the caller)
///   - a redacted / hashed docId (never the raw id, to stay privacy-safe)
///   - the field name
///   - the observed runtime type (NOT the value, to avoid leaking PII)
///
/// Records are rate-limited per (field, observedType) signature so a single
/// malformed query result cannot flood the log.
class ParseDiagnostics {
  ParseDiagnostics._();

  /// Max log emissions per distinct signature within [_window].
  static const int _maxPerWindow = 3;
  static const Duration _window = Duration(minutes: 5);

  /// signature -> (count, windowStart).
  static final Map<String, _RateBucket> _buckets = {};

  /// Test seam: lets unit tests assert what was recorded without scraping logs.
  /// Null in production (zero overhead beyond a null check).
  @visibleForTesting
  static List<ParseDiagnosticRecord>? captured;

  /// Test seam: reset rate-limit state between tests.
  @visibleForTesting
  static void reset() {
    _buckets.clear();
    captured?.clear();
  }

  /// Records a single parse fallback. Never throws.
  ///
  /// [collection] is a logical area label (caller-supplied, optional).
  /// [docId] is redacted before logging. [field] is the field that failed.
  /// [observedType] is the runtime type that was seen instead of the expected.
  static void record({
    String? collection,
    String? docId,
    required String field,
    required String observedType,
    String? note,
  }) {
    try {
      final record = ParseDiagnosticRecord(
        collection: collection,
        redactedDocId: _redact(docId),
        field: field,
        observedType: observedType,
        note: note,
      );
      captured?.add(record);

      final signature = '${collection ?? ''}:$field:$observedType';
      if (!_allow(signature)) return;

      final buf = StringBuffer('parse_fallback ');
      if (collection != null) buf.write('collection=$collection ');
      buf.write('field=$field observedType=$observedType');
      if (record.redactedDocId != null) {
        buf.write(' docId=${record.redactedDocId}');
      }
      if (note != null) buf.write(' note=$note');

      developer.log(buf.toString(), name: 'safe_parse');
      // debugPrint mirrors it to logcat in profile/release internal builds.
      debugPrint('[safe_parse] $buf');
    } catch (_) {
      // Diagnostics must never break a parse. Swallow everything.
    }
  }

  /// Redacts a docId to a short, non-reversible token: first 2 chars + a
  /// stable non-cryptographic hash of the whole id. Enough to correlate
  /// repeated failures on the same doc without exposing the id itself.
  static String? _redact(String? docId) {
    if (docId == null || docId.isEmpty) return null;
    final prefix = docId.length <= 2 ? docId : docId.substring(0, 2);
    return '$prefix..#${_stableHash(docId)}';
  }

  // FNV-1a 32-bit, just for log correlation (not security).
  static int _stableHash(String s) {
    var hash = 0x811c9dc5;
    for (final code in s.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  static bool _allow(String signature) {
    final now = DateTime.now();
    final bucket = _buckets[signature];
    if (bucket == null || now.difference(bucket.windowStart) > _window) {
      _buckets[signature] = _RateBucket(count: 1, windowStart: now);
      return true;
    }
    if (bucket.count >= _maxPerWindow) return false;
    bucket.count++;
    return true;
  }
}

class _RateBucket {
  int count;
  final DateTime windowStart;
  _RateBucket({required this.count, required this.windowStart});
}

/// A captured diagnostic (test-only inspection).
class ParseDiagnosticRecord {
  final String? collection;
  final String? redactedDocId;
  final String field;
  final String observedType;
  final String? note;

  const ParseDiagnosticRecord({
    this.collection,
    this.redactedDocId,
    required this.field,
    required this.observedType,
    this.note,
  });

  @override
  String toString() =>
      'ParseDiagnosticRecord(collection: $collection, field: $field, '
      'observedType: $observedType, docId: $redactedDocId, note: $note)';
}
