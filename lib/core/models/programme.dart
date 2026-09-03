import '../utils/safe_parse.dart';

/// One programme from the catalogue: `programmes/{programmeId}` in
/// `teacher-corner-dev`.
///
/// DISTINCT FROM THE TWO DENORMALISED COPIES, and keeping the three apart is the
/// point of this class existing:
///
///   * [ProgrammeRef]        the copy nested on `teachers/{id}.classrooms[]`.
///                           Two fields: the id and a display name.
///   * [ClassroomProgramme]  the copy nested on `classrooms/{id}.programmes`.
///                           Adds the per-classroom workflow bindings.
///   * [Programme]           THIS. The catalogue document, and the only place
///                           the description, code, grades and status exist.
///
/// So the classroom screens can name a programme without a read, and only the
/// programme detail screen pays for one.
///
/// EVERY FIELD BELOW IS PRESENT ON EVERY DOCUMENT in that collection, verified
/// by dumping the field union across all of them rather than sampling one. That
/// is why so few are nullable: absence here means the document was written by
/// something other than the Teacher Corner web app, not that the field is
/// optional in practice. Nothing is modelled that does not exist — there is no
/// enrolment count, no schedule and no progress on a programme document, so
/// this class does not pretend otherwise.
class Programme {
  const Programme({
    required this.programmeId,
    this.programmeName,
    this.displayName,
    this.programmeCode,
    this.description,
    this.institutionId,
    this.institutionName,
    this.grades = const [],
    this.ages = const [],
    this.type,
    this.status,
    this.learningUnitIds = const [],
    this.assignments = const {},
    this.imagePath,
    this.createdAt,
    this.updatedAt,
  });

  /// The document id. Also mirrored in the document's own `programmeId` and
  /// `docId` fields, which are ignored: the id you read a document by is the
  /// only one that cannot disagree with where it lives.
  final String programmeId;

  /// The catalogue name. Can differ from [displayName] — one live document is
  /// named "Stiles fun" and displays as "Funnn".
  final String? programmeName;

  /// What the UI shows, when set. See [label] for the resolution order.
  final String? displayName;

  /// Sequential code, `P` then five digits: `P10017`.
  final String? programmeCode;

  /// `programmeDescription` on the document. Free text, and often short.
  final String? description;

  final String? institutionId;
  final String? institutionName;

  /// Which grades it covers, as STRINGS, and stored EXPANDED rather than as
  /// endpoints: grades 4 to 9 is `['4','5','6','7','8','9']`. Strings because
  /// the same list mixes `'9'` with pre-primary labels. See [gradeRange] for the
  /// display form.
  final List<String> grades;

  /// The alternative to [grades]: the age band a programme is written for. The
  /// web app's form is an either/or, so one of the two is normally empty.
  final List<String> ages;

  /// `REGULAR` or `STEM-CLUB`. The web app maps a classroom of type `CLASSROOM`
  /// to a programme of type `REGULAR`, so the two vocabularies differ on
  /// purpose.
  final String? type;

  /// `LIVE` or `DEVELOPEMENT` — misspelled in the stored data, and matched as
  /// stored rather than corrected, because correcting it here would fail to
  /// match every document already written. See [isLive].
  final String? status;

  /// Learning units attached to this programme. EMPTY on every document in this
  /// database today; the collection those ids would point at has no documents.
  final List<String> learningUnitIds;

  /// Assignments allotted to this programme, keyed by assignment doc id, with
  /// the due date the programme set for each.
  ///
  /// A MAP, NOT AN ARRAY, and this was wrong before. It was parsed with
  /// `asStringList`, which returns nothing for a map, so the field read as empty
  /// on every document and the old comment recorded that as a fact about the
  /// data. It is a fact about the parser: 2 of the 20 programmes in this database
  /// carry the field, both as maps, and production has it on 2715 of 14240.
  ///
  /// Every entry is shaped `{ assignmentId, assignmentDueDate }` and the key
  /// always equals the `assignmentId` inside it, so the key is the id and the
  /// value contributes only the date.
  ///
  /// ORDER DOES NOT MATTER, unlike [learningUnitIds]. A map has none to preserve,
  /// which is why the web app's picker for these offers no reordering.
  final Map<String, DateTime?> assignments;

  /// The allotted assignment ids. Order is not meaningful — see [assignments].
  List<String> get assignmentIds => assignments.keys.toList(growable: false);

  /// Storage path of the thumbnail, e.g. `programme_images/{id}.png`. Empty
  /// string on every document today, which is why [imagePath] is null rather
  /// than `''` when blank: an empty path is not a path.
  final String? imagePath;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const String collection = 'programmes';

  /// A display string, with BLANK TREATED AS ABSENT.
  ///
  /// `SafeParse.asDisplayString` passes an empty string straight through, which
  /// is right in general — some fields are meaningfully empty. Here it is not:
  /// every one of these fields is written on every document by the web app, so a
  /// blank means "nobody filled this in", and a caller checking `!= null` would
  /// otherwise render an empty About section or try to resolve `''` as a Storage
  /// path. `programmeImagePath` is `''` on every live document today, which is
  /// exactly the case this exists for.
  static String? _text(dynamic value) {
    final raw = SafeParse.asDisplayString(value);
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  factory Programme.fromMap(String programmeId, Map<String, dynamic> data) {
    return Programme(
      programmeId: programmeId,
      programmeName: _text(data['programmeName']),
      displayName: _text(data['displayName']),
      programmeCode: _text(data['programmeCode']),
      description: _text(data['programmeDescription']),
      institutionId: _text(data['institutionId']),
      institutionName: _text(data['institutionName']),
      // ListPolicy.skip, not fail: one unparseable entry in a grade list must
      // cost that entry, not the whole programme screen.
      grades:
          SafeParse.asStringList(
            data['grades'],
            collection: collection,
            docId: programmeId,
            field: 'grades',
          ) ??
          const [],
      ages:
          SafeParse.asStringList(
            data['age'],
            collection: collection,
            docId: programmeId,
            field: 'age',
          ) ??
          const [],
      type: _text(data['type']),
      status: _text(data['programmeStatus']),
      learningUnitIds:
          SafeParse.asStringList(
            data['learningUnitsIds'],
            collection: collection,
            docId: programmeId,
            field: 'learningUnitsIds',
          ) ??
          const [],
      assignments: _assignments(data['assignmentIds'], programmeId),
      imagePath: _text(data['programmeImagePath']),
      createdAt: SafeParse.asDate(
        data['createdAt'],
        collection: collection,
        docId: programmeId,
        field: 'createdAt',
      ),
      updatedAt: SafeParse.asDate(
        data['updatedAt'],
        collection: collection,
        docId: programmeId,
        field: 'updatedAt',
      ),
    );
  }

  /// Never blank and never the string "null": display name, then the catalogue
  /// name, then the id.
  ///
  /// The id is a real fallback rather than a placeholder. A programme whose
  /// names are both blank is still a programme the teacher can be looking at,
  /// and an id at least identifies which one.
  String get label {
    for (final candidate in [displayName, programmeName]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return programmeId;
  }

  /// True only for the stored literal `LIVE`.
  ///
  /// Anything else is a draft, which is the defensive reading: the field is a
  /// bare string in the data and this app has not enumerated every value it
  /// holds, so an unrecognised status lands under "not live" rather than being
  /// silently promoted.
  bool get isLive => (status ?? '').toUpperCase() == 'LIVE';

  bool get isStemClub => (type ?? '').toUpperCase() == 'STEM-CLUB';

  /// "4 - 9" for a contiguous numeric run, "4, 6, 9" when it has gaps, and the
  /// values verbatim when they are not numeric at all.
  ///
  /// Re-derived for display because the data stores the range EXPANDED. Null
  /// rather than an empty string when there are no grades, so the caller omits
  /// the line instead of rendering a label with nothing after it.
  String? get gradeRange {
    if (grades.isEmpty) return null;

    final numbers = <int>[];
    for (final grade in grades) {
      final n = int.tryParse(grade.trim());
      // A single non-numeric entry makes the whole list unsummarisable, so fall
      // back to listing it rather than guessing at a range around it.
      if (n == null) return grades.join(', ');
      numbers.add(n);
    }
    numbers.sort();

    final contiguous = numbers.last - numbers.first == numbers.length - 1;
    if (contiguous && numbers.length > 1) {
      return '${numbers.first} - ${numbers.last}';
    }
    return numbers.join(', ');
  }

  /// The age band, same treatment as [gradeRange]. Null when none is stored,
  /// which is the normal case for a grade-scoped programme.
  String? get ageRange {
    if (ages.isEmpty) return null;
    return ages.join(', ');
  }
}

/// `assignmentIds` off a programme document: a map of id to due date.
///
/// TOLERATES THE ARRAY SHAPE TOO. `--schema--` in production's collection carries
/// `assignmentsIds` — with an extra 's' — as an array of two strings, and a
/// hand-edited document could plausibly hold a plain array here. An array is read
/// as ids with no due date rather than dropped, because an assignment with an
/// unknown date is still allotted.
Map<String, DateTime?> _assignments(dynamic raw, String programmeId) {
  final out = <String, DateTime?>{};

  if (raw is List) {
    for (final entry in raw) {
      final id = SafeParse.asDisplayString(entry);
      if (id != null && id.isNotEmpty) out[id] = null;
    }

    return Map.unmodifiable(out);
  }

  if (raw is! Map) return const {};

  raw.forEach((key, value) {
    final id = key.toString().trim();

    if (id.isEmpty) return;

    final fields = value is Map
        ? value.map((k, v) => MapEntry(k.toString(), v))
        : const <String, dynamic>{};

    out[id] = SafeParse.asDate(
      fields['assignmentDueDate'],
      collection: Programme.collection,
      docId: programmeId,
      field: 'assignmentIds.$id.assignmentDueDate',
    );
  });

  return Map.unmodifiable(out);
}
