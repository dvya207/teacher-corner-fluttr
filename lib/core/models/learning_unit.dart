import '../utils/safe_parse.dart';
import 'learning_unit_additional_resource.dart';
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
    this.alternateLongDescription,
    this.alternateShortDescription,
    this.tinyDescription,
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
    this.additionalResources = const [],
  });

  final String learningUnitId;
  final String? displayName;
  final String? type;
  final String? shortDescription;
  final String? longDescription;

  /// THREE MORE DESCRIPTION FIELDS, and they were being dropped. Every unit in
  /// teacher-corner-dev that has a description has all five of these filled,
  /// with different text in each; the model read two and ignored the rest, so a
  /// unit whose author had only filled an alternate or the tiny one showed no
  /// description at all.
  final String? alternateLongDescription;
  final String? alternateShortDescription;
  final String? tinyDescription;

  /// The description to SHOW, from whichever field has one.
  ///
  /// LONGEST FIRST, then progressively shorter, because this is read on a
  /// screen a teacher opens BEFORE running the activity: they are deciding
  /// whether they understand it well enough to teach it, and more detail is
  /// better. The tiny one is a last resort rather than a preference.
  ///
  /// ONE GETTER RATHER THAN A CHAIN AT EACH CALL SITE, because there were two
  /// call sites and they disagreed: the overview screen preferred the long
  /// description and the step screen's About block preferred the short one, so
  /// the same unit read differently on two screens one tap apart.
  String? get description {
    for (final candidate in [
      longDescription,
      shortDescription,
      alternateLongDescription,
      alternateShortDescription,
      tinyDescription,
    ]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
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

  /// The unit document's own `resources` map, and it holds TWO UNRELATED
  /// KINDS OF VALUE under one roof. Knowing that is the whole point of the
  /// accessors below.
  ///
  ///   resources.gold           = "1eXvhUXV7st…"    a DOCUMENT ID, store one
  ///   resources.materialPath   = "learningUnits/…/Sample.pdf"   a FILE
  ///   resources.videoUrl       = "https://youtube.com/…"        a LINK
  ///
  /// The maturity keys point at `learningUnitResources` documents, one per
  /// rung, which is where most of a unit's uploads live. The rest are the web
  /// app's nine "External Resources", which have NO maturity and live right
  /// here on the unit: the editor's External Resources tab has no maturity
  /// selector for exactly this reason.
  ///
  /// THIS SECOND STORE IS WHY SIX TABS RENDERED EMPTY. A workflow step reaches
  /// these nine with `contentCategory: 'externalResources'`, and this app only
  /// ever looked in the maturity documents, so Material List, Observation
  /// Sheet, Evidence Uploads and the rest all resolved to nothing while the
  /// files sat here. See [externalResourcePath].
  final Map<String, String> resources;

  /// Extra files the author attached beyond the standard slots, in document
  /// order. See [LearningUnitAdditionalResource].
  final List<LearningUnitAdditionalResource> additionalResources;

  /// The ones a teacher should actually see. A draft is not hidden by accident:
  /// `publish: false` is set deliberately by whoever attached it.
  List<LearningUnitAdditionalResource> get publishedAdditionalResources => [
    for (final r in additionalResources)
      if (r.publish) r,
  ];

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
  ///
  /// CASE-INSENSITIVE, and it has to be: the two halves of this lookup
  /// disagree in live data. The unit's own field is capitalised,
  /// `Maturity: "Gold"`, while the key inside its `resources` map is
  /// lowercase, `resources.gold`. An exact lookup therefore missed on every
  /// real unit and this getter answered null for all six of them.
  String? get resourceIdForMaturity {
    final key = maturity?.trim().toLowerCase();
    if (key == null || key.isEmpty) return null;
    for (final entry in resources.entries) {
      if (entry.key.toLowerCase() == key) {
        final value = entry.value.trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  /// The maturity rungs, which are the keys of [resources] whose values are
  /// document ids rather than files.
  ///
  /// Lowercase, because the ladder is written lowercase in the map even though
  /// the unit's own `Maturity` field is capitalised ('Gold').
  static const Set<String> maturityKeys = {
    'bronze',
    'silver',
    'gold',
    'platinum',
    'diamond',
  };

  /// The category a workflow step uses to point at an External Resource.
  ///
  /// Not one of production's resource categories. The web app added it so a
  /// step could name a file a teacher had uploaded on the External Resources
  /// tab, which was otherwise unreachable from any step.
  static const String externalResourcesCategory = 'externalresources';

  /// The External Resource in one slot, or null when that slot is empty.
  ///
  /// NAMED SLOTS ARE NOT WHITELISTED, the maturity rungs are blacklisted
  /// instead. The nine slots are a list the web app maintains and production's
  /// sheet can add to; a whitelist here would silently hide the tenth. What
  /// must never come back from this is a maturity value, because that is a
  /// document id and handing it to a viewer asks Storage for a file that is
  /// not there.
  String? externalResourcePath(String? slot) {
    final key = slot?.trim();
    if (key == null || key.isEmpty) return null;
    if (maturityKeys.contains(key.toLowerCase())) return null;
    final value = resources[key]?.trim();
    return (value == null || value.isEmpty) ? null : value;
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
      alternateLongDescription: SafeParse.asDisplayString(
        data['alternateLongDescription'],
      ),
      alternateShortDescription: SafeParse.asDisplayString(
        data['alternateShortDescription'],
      ),
      tinyDescription: SafeParse.asDisplayString(data['tinyDescription']),
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
      // `learningUnitImage` FIRST, because that is the one the web app fills.
      //
      // Both fields exist on a live document and only one is ever populated:
      // `learningUnitImage` holds
      // "learningUnits/{docId}/learningUnitImage.jpg" while
      // `learningUnitPreviewImage` sits empty. Reading only the preview field
      // meant every activity card rendered with no picture, and the card had no
      // way to tell "this activity has no image" from "we looked in the wrong
      // place". The preview field is kept as a fallback rather than dropped,
      // since nothing here proves it is never used.
      previewImagePath: SafeParse.asRefString(
        _firstNonEmpty(data, const [
          'learningUnitImage',
          'learningUnitPreviewImage',
        ]),
        collection: collection,
        docId: learningUnitId,
        field: 'learningUnitPreviewImage',
      ),
      maturity: SafeParse.asDisplayString(data['Maturity']),
      resources: Map.unmodifiable(resources),
      additionalResources: LearningUnitAdditionalResource.listFrom(
        data[LearningUnitAdditionalResource.field],
        docId: learningUnitId,
      ),
    );
  }
}

/// The first of [keys] whose value is a non-empty string, or null.
///
/// A helper rather than a chain of `??`, because "present but empty string" is
/// the case that matters here and `??` only catches null.
///
/// NULL WHEN EVERY CANDIDATE IS EMPTY, which is not fussiness. An empty path
/// is not falsy to a widget: the card guards on `previewImagePath != null`, so
/// returning "" made it ask Firebase Storage for the empty path and draw a
/// broken-image box on every activity. Absent has to arrive as absent.
Object? _firstNonEmpty(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isEmpty) continue;
    if (value != null) return value;
  }
  return null;
}
