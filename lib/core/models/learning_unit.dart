import '../utils/safe_parse.dart';

/// `LearningUnits/{luId}`: the activity itself, shared across classrooms.
///
/// Note what is NOT here: which workflow to run. That is a property of the
/// classroom, not of the activity. See [WorkflowBinding] on `Classroom`.
class LearningUnit {
  const LearningUnit({
    required this.learningUnitId,
    this.displayName,
    this.type,
    this.shortDescription,
    this.longDescription,
    this.stepCount,
    this.subjectName,
    this.previewImagePath,
    this.maturity,
    this.resources = const {},
  });

  final String learningUnitId;
  final String? displayName;
  final String? type;
  final String? shortDescription;
  final String? longDescription;
  final int? stepCount;
  final String? subjectName;

  /// A Cloud Storage PATH, not a download URL.
  ///
  /// Resolving it costs a `getDownloadURL()` call, and every such call mints a
  /// fresh access token into the result, so the same file yields a different URL
  /// every time. Any cache must therefore be keyed on THIS path and never on
  /// the URL, or it will never hit and will silently re-download forever.
  final String? previewImagePath;

  /// Field name on the document is capitalised: `Maturity`.
  final String? maturity;

  /// Maturity level to `LearningUnitResources` document id.
  final Map<String, String> resources;

  /// `learningUnits`, LOWERCASE: the web app's collection name in
  /// `teacher-corner-dev`, not production's `LearningUnits`.
  ///
  /// THE COLLECTION IS PRESENT BUT EMPTY as of the repoint, and the web app
  /// stores a NARROWER document than this model reads: `stepCount`,
  /// `longDescription`, `learningUnitPreviewImage` and `resources` are all
  /// absent from its `LearningUnit` interface. Every one of those is nullable
  /// or defaulted here, so a real web-app document parses and degrades rather
  /// than throwing.
  static const String collection = 'learningUnits';

  /// Never blank, never "null": three possible field names in descending
  /// preference, then the id.
  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return learningUnitId;
  }

  /// The resource document for this unit's own maturity, when there is one.
  String? get resourceIdForMaturity {
    final key = maturity?.trim();
    if (key == null || key.isEmpty) return null;
    return resources[key];
  }

  factory LearningUnit.fromMap(
    String learningUnitId,
    Map<String, dynamic> data,
  ) {
    // SCHEMA.md gives three names for the same field, in this order of
    // preference, because three systems wrote this collection over the years.
    final name =
        SafeParse.asDisplayString(data['learningUnitDisplayName']) ??
        SafeParse.asDisplayString(data['learningUnitName']) ??
        SafeParse.asDisplayString(data['name']);

    final rawResources = SafeParse.asStringKeyedMap(
      data['resources'],
      collection: collection,
      docId: learningUnitId,
      field: 'resources',
    );
    final resources = <String, String>{};
    rawResources.forEach((key, value) {
      // Strict: a resource id is a document id, and fabricating one from a
      // number would point at the wrong document rather than at nothing.
      final id = SafeParse.asRefString(
        value,
        collection: collection,
        docId: learningUnitId,
        field: 'resources.$key',
      );
      if (id != null && id.isNotEmpty) resources[key] = id;
    });

    return LearningUnit(
      learningUnitId: learningUnitId,
      displayName: name,
      type: SafeParse.asDisplayString(data['type']),
      shortDescription: SafeParse.asDisplayString(data['shortDescription']),
      longDescription: SafeParse.asDisplayString(data['longDescription']),
      stepCount: SafeParse.asIntOrNull(
        data['stepCount'],
        collection: collection,
        docId: learningUnitId,
        field: 'stepCount',
      ),
      subjectName: SafeParse.asDisplayString(data['subjectName']),
      previewImagePath: SafeParse.asRefString(
        data['learningUnitPreviewImage'],
        collection: collection,
        docId: learningUnitId,
        field: 'learningUnitPreviewImage',
      ),
      maturity: SafeParse.asDisplayString(data['Maturity']),
      resources: Map.unmodifiable(resources),
    );
  }
}
