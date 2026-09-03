import '../utils/safe_parse.dart';
import 'learning_unit_taxonomy.dart';

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
    this.learningUnitCode,
    this.subjectCode,
    this.subjectName,
    this.domainCode,
    this.domainName,
    this.subDomainCode,
    this.subDomainName,
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

  /// `[A-Z]{2}[0-9]{2}`, e.g. `BO07`. The ONLY reliable categorisation field.
  ///
  /// Present and well-formed on 598/598 sampled production documents, where the
  /// stored names beside it are wrong on roughly one in twelve. Not the document
  /// id: ids are Firestore auto-ids and never codes.
  final String? learningUnitCode;

  // The categorisation as the DOCUMENT stores it. Read through
  // [categorisation] rather than directly — these are the unreliable copies,
  // kept only so they can serve as a fallback for a code the table
  // does not know. See learning_unit_taxonomy.dart for the measurements.
  final String? subjectCode;
  final String? subjectName;
  final String? domainCode;
  final String? domainName;
  final String? subDomainCode;
  final String? subDomainName;

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

  /// Subject, domain and sub-domain, derived from [learningUnitCode] where the
  /// table knows it and fell back to the stored fields where it does not.
  ///
  /// Computed rather than stored so a Firestore override installed after this
  /// object was parsed is picked up on the next read.
  LearningUnitCategorisation get categorisation =>
      LearningUnitTaxonomy.instance.resolve(
        code: learningUnitCode,
        storedSubjectCode: subjectCode,
        storedSubjectName: subjectName,
        storedDomainCode: domainCode,
        storedDomainName: domainName,
        storedSubDomainCode: subDomainCode,
        storedSubDomainName: subDomainName,
      );

  /// The subject to SHOW. Prefers the derived name over the stored one.
  ///
  /// [subjectName] is the raw field and stays available; this is what a widget
  /// should render.
  String? get resolvedSubjectName => categorisation.subjectName;

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
      learningUnitCode: SafeParse.asDisplayString(data['learningUnitCode']),
      subjectCode: SafeParse.asDisplayString(data['subjectCode']),
      subjectName: SafeParse.asDisplayString(data['subjectName']),
      domainCode: SafeParse.asDisplayString(data['domainCode']),
      domainName: SafeParse.asDisplayString(data['domainName']),
      subDomainCode: SafeParse.asDisplayString(data['subDomainCode']),
      subDomainName: SafeParse.asDisplayString(data['subDomainName']),
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
