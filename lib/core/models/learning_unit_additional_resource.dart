import '../utils/safe_parse.dart';

/// One extra file a learning unit carries beyond its standard resource slots.
///
/// A SECOND, SEPARATE PLACE FROM `learningUnitResources`. The standard slots
/// there are a fixed vocabulary the app looks up by
/// `category.subCategory`; these are free-form additions the author names
/// themselves, stored as an array on the learning unit document. A workflow
/// step points at them with `contentCategory: "additional resources"` and no
/// subCategory, because there is no fixed key to point at.
class LearningUnitAdditionalResource {
  const LearningUnitAdditionalResource({
    required this.resourcePath,
    this.title,
    this.description,
    this.type,
    this.fileExtension,
    this.publish = true,
  });

  static const String field = 'additionalResources';

  /// A URL for a `VIDEO`, a Storage path for an `UPLOAD`. Never empty: an entry
  /// without one is dropped at parse time, since there is nothing to open.
  final String resourcePath;

  final String? title;
  final String? description;

  /// `VIDEO` or `UPLOAD` in live data.
  final String? type;

  /// `video`, `pdf`, `pptx`. What the row shows a teacher, and what a step's
  /// `additionalResourceType` is matched against.
  final String? fileExtension;

  /// False for a draft the author has not released.
  ///
  /// DEFAULTS TO TRUE for an entry that omits the field. A resource somebody
  /// took the trouble to attach is more likely finished than not, and hiding a
  /// teacher's own upload on a missing boolean is the worse mistake.
  final bool publish;

  /// Never blank and never "null", so a row always has something to name it.
  String get label {
    final name = title?.trim();
    if (name != null && name.isNotEmpty) return name;
    final kind = fileExtension?.trim();
    return (kind != null && kind.isNotEmpty) ? kind.toUpperCase() : type ?? '';
  }

  /// Whether this answers a step content asking for [wanted], e.g. "PPT".
  ///
  /// Prefix, not equality: a slot says "PPT" and the file says "pptx", and the
  /// same holds for every other pair in this data.
  bool matchesType(String? wanted) {
    final want = wanted?.trim().toLowerCase();
    if (want == null || want.isEmpty) return false;
    final ext = fileExtension?.trim().toLowerCase() ?? '';
    final kind = type?.trim().toLowerCase() ?? '';
    return ext.startsWith(want) || want.startsWith(ext) && ext.isNotEmpty ||
        kind == want;
  }

  static List<LearningUnitAdditionalResource> listFrom(
    Object? raw, {
    String? docId,
  }) {
    if (raw is! List) return const [];
    final parsed = <LearningUnitAdditionalResource>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final data = <String, dynamic>{
        for (final e in entry.entries) '${e.key}': e.value,
      };
      final path = SafeParse.asRefString(
        data['resourcePath'],
        docId: docId,
        field: '$field.resourcePath',
      );
      // Nothing to open, so nothing to show. An entry with a title and no file
      // would render a row that does nothing when tapped.
      if (path == null || path.isEmpty) continue;

      parsed.add(
        LearningUnitAdditionalResource(
          resourcePath: path,
          title: SafeParse.asDisplayString(data['title']),
          // LOWERCASE `shortdescription` is what the web app writes. The
          // camelCase spelling is accepted too rather than assumed absent.
          description: SafeParse.asDisplayString(
            data['shortdescription'] ?? data['shortDescription'],
          ),
          type: SafeParse.asDisplayString(data['type']),
          fileExtension: SafeParse.asDisplayString(data['fileExtension']),
          publish: data['publish'] is bool ? data['publish'] as bool : true,
        ),
      );
    }
    return List.unmodifiable(parsed);
  }
}
