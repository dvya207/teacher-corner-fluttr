/// subject → domain → sub-domain, keyed on the two letters of a learning unit
/// code.
///
/// WHY THIS EXISTS HERE, WHEN THE DOCUMENT ALREADY CARRIES THE NAMES.
/// Every production `LearningUnits` document stores its own `subjectName`,
/// `domainName` and `subDomainName`, so reading them looks like the obvious
/// move. It is not, because those fields are wrong often enough to matter. Over
/// 598 sampled production documents, checking the stored `domainCode` and
/// `subDomainCode` against the first two characters of `learningUnitCode`:
///
///   549 agree, 49 do not — roughly one unit in twelve.
///
/// The disagreements come in three kinds, and only the first two are gaps:
///
///   absent      FE05, GH11 — the fields are simply not on the document
///   empty       PL06, PM08 — present and set to ''
///   CONTRADICTS BA05 — code says domain B, sub-domain A; the document says
///                      domainCode 'B', subDomainCode 'E'
///
/// `domainName` is the thinnest of the set at 537/598. `learningUnitCode`, by
/// contrast, is on 598/598 and matches [kLearningUnitCodePattern] every single
/// time. So the code is the reliable field and the names are the unreliable
/// ones, which is why resolution derives from the code FIRST and treats the
/// stored names as the fallback rather than the source. See
/// [LearningUnitTaxonomy.resolve].
///
/// WHERE THE ROWS COME FROM. `Configuration/learningUnitDomains.domains` in
/// `teacher-corner-dev`, 44 rows, seeded there out of the Angular web app's
/// `src/app/data/learning-unit-taxonomy.ts`. The rows below were generated from
/// that same file rather than retyped, so the three copies cannot drift by
/// transcription. A console edit to the Firestore document still wins at
/// runtime: see [LearningUnitTaxonomy.replaceDefault].
///
/// The digits of a code are a serial number and carry no meaning. The letter
/// pair is the whole lookup, and it is unique across all 44 rows.
library;

/// One row of `Configuration/learningUnitDomains.domains`, field for field.
class TaxonomyRow {
  const TaxonomyRow({
    required this.subjectCode,
    required this.subjectName,
    required this.domainCode,
    required this.domainName,
    required this.subDomainCode,
    required this.subDomainName,
  });

  final String subjectCode;
  final String subjectName;

  /// ONE character — the first character of a learning unit code.
  final String domainCode;
  final String domainName;

  /// ONE character — the second character of a learning unit code.
  final String subDomainCode;
  final String subDomainName;

  /// Domain code then sub-domain code, concatenated: `AE04` gives `AE`.
  ///
  /// Production writes exactly this into its own `compositeCode` field. It is
  /// the two letters and nothing richer, which is worth naming because a reader
  /// would otherwise expect the full code.
  String get compositeCode => '$domainCode$subDomainCode';

  /// One entry of `Configuration/learningUnitDomains.domains`.
  ///
  /// MIND THE CASING. That document spells the sub-domain NAME `subdomainName`
  /// with a lowercase `d`, while the sub-domain CODE beside it is
  /// `subDomainCode` with a capital one. Verified against the live document, not
  /// assumed. Both spellings are accepted here so the seeded copy and the
  /// camelCase the rest of the codebase uses both parse, rather than the row
  /// silently arriving with a blank sub-domain name.
  factory TaxonomyRow.fromMap(Map<String, dynamic> data) {
    String at(String key) => (data[key] as Object?)?.toString().trim() ?? '';
    String either(String a, String b) {
      final first = at(a);
      return first.isNotEmpty ? first : at(b);
    }

    return TaxonomyRow(
      subjectCode: at('subjectCode'),
      subjectName: at('subjectName'),
      domainCode: at('domainCode'),
      domainName: at('domainName'),
      subDomainCode: either('subDomainCode', 'subdomainCode'),
      subDomainName: either('subdomainName', 'subDomainName'),
    );
  }
}

/// `[A-Z]{2}[0-9]{2}` — two letters then two digits.
///
/// Anchored at BOTH ends. The web app's input pattern is `[A-Z]{2}[0-9]{2}$`,
/// unanchored at the start and safe only because a `maxlength` attribute sits
/// beside it. Anchoring here means the check does not depend on a second rule
/// agreeing with it.
final RegExp kLearningUnitCodePattern = RegExp(r'^[A-Z]{2}[0-9]{2}$');

/// All 44 rows. Generated from the web app's taxonomy file, not retyped.
const List<TaxonomyRow> kLearningUnitTaxonomy = [
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'A',
    domainName: 'Algebra',
    subDomainCode: 'E',
    subDomainName: 'Equations',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'A',
    domainName: 'Algebra',
    subDomainCode: 'V',
    subDomainName: 'Variables and Expressions',
  ),

  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'B',
    domainName: 'Biology',
    subDomainCode: 'A',
    subDomainName: 'Animal',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'B',
    domainName: 'Biology',
    subDomainCode: 'E',
    subDomainName: 'Ecosystem',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'B',
    domainName: 'Biology',
    subDomainCode: 'M',
    subDomainName: 'Microbes',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'B',
    domainName: 'Biology',
    subDomainCode: 'O',
    subDomainName: 'Other',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'B',
    domainName: 'Biology',
    subDomainCode: 'P',
    subDomainName: 'Plant',
  ),

  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'C',
    domainName: 'Chemistry',
    subDomainCode: 'C',
    subDomainName: 'Chemical Reactions',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'C',
    domainName: 'Chemistry',
    subDomainCode: 'H',
    subDomainName: 'Heat',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'C',
    domainName: 'Chemistry',
    subDomainCode: 'M',
    subDomainName: 'Mixtures',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'C',
    domainName: 'Chemistry',
    subDomainCode: 'O',
    subDomainName: 'Others',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'C',
    domainName: 'Chemistry',
    subDomainCode: 'P',
    subDomainName: 'Properties of Matter',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'C',
    domainName: 'Chemistry',
    subDomainCode: 'Q',
    subDomainName: 'Measurements',
  ),

  TaxonomyRow(
    subjectCode: 'E',
    subjectName: 'Earth Sciences',
    domainCode: 'E',
    domainName: 'Earth Sciences',
    subDomainCode: 'E',
    subDomainName: 'Earth',
  ),
  TaxonomyRow(
    subjectCode: 'E',
    subjectName: 'Earth Sciences',
    domainCode: 'E',
    domainName: 'Earth Sciences',
    subDomainCode: 'R',
    subDomainName: 'Recycling',
  ),
  TaxonomyRow(
    subjectCode: 'E',
    subjectName: 'Earth Sciences',
    domainCode: 'E',
    domainName: 'Earth Sciences',
    subDomainCode: 'S',
    subDomainName: 'Space',
  ),

  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'G',
    domainName: 'Geometry',
    subDomainCode: 'B',
    subDomainName: 'Comparision of Shapes',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'G',
    domainName: 'Geometry',
    subDomainCode: 'C',
    subDomainName: 'Coordinate Geometry',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'G',
    domainName: 'Geometry',
    subDomainCode: 'D',
    subDomainName: 'Dimensions',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'G',
    domainName: 'Geometry',
    subDomainCode: 'M',
    subDomainName: 'Mensuration',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'G',
    domainName: 'Geometry',
    subDomainCode: 'S',
    subDomainName: 'Shapes',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'G',
    domainName: 'Geometry',
    subDomainCode: 'T',
    subDomainName: 'Trigonometry',
  ),

  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'N',
    domainName: 'Numbers',
    subDomainCode: 'B',
    subDomainName: 'Financial Maths',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'N',
    domainName: 'Numbers',
    subDomainCode: 'F',
    subDomainName: 'Fractions',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'N',
    domainName: 'Numbers',
    subDomainCode: 'L',
    subDomainName: 'Log and Exponents',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'N',
    domainName: 'Numbers',
    subDomainCode: 'M',
    subDomainName: 'Measurements',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'N',
    domainName: 'Numbers',
    subDomainCode: 'N',
    subDomainName: 'Numbers',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'N',
    domainName: 'Numbers',
    subDomainCode: 'O',
    subDomainName: 'Operators',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'N',
    domainName: 'Numbers',
    subDomainCode: 'P',
    subDomainName: 'Progressions',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'N',
    domainName: 'Numbers',
    subDomainCode: 'S',
    subDomainName: 'Sets',
  ),

  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'P',
    domainName: 'Physics',
    subDomainCode: 'E',
    subDomainName: 'Energy',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'P',
    domainName: 'Physics',
    subDomainCode: 'F',
    subDomainName: 'Force',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'P',
    domainName: 'Physics',
    subDomainCode: 'L',
    subDomainName: 'Light',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'P',
    domainName: 'Physics',
    subDomainCode: 'M',
    subDomainName: 'Electricity & Magnetism',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'P',
    domainName: 'Physics',
    subDomainCode: 'S',
    subDomainName: 'Sound',
  ),
  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'P',
    domainName: 'Physics',
    subDomainCode: 'T',
    subDomainName: 'Motion',
  ),

  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'S',
    domainName: 'Statistics',
    subDomainCode: 'C',
    subDomainName: 'Central Tendancy',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'S',
    domainName: 'Statistics',
    subDomainCode: 'G',
    subDomainName: 'Graphs',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'S',
    domainName: '',
    subDomainCode: 'M',
    subDomainName: 'Motors',
  ),
  TaxonomyRow(
    subjectCode: 'M',
    subjectName: 'Mathematics',
    domainCode: 'S',
    domainName: 'Statistics',
    subDomainCode: 'P',
    subDomainName: 'Probability',
  ),

  TaxonomyRow(
    subjectCode: 'T',
    subjectName: 'Toys and Tales',
    domainCode: 'T',
    domainName: 'Toys and Tales',
    subDomainCode: 'F',
    subDomainName: 'Food',
  ),
  TaxonomyRow(
    subjectCode: 'T',
    subjectName: 'Toys and Tales',
    domainCode: 'T',
    domainName: 'Toys and Tales',
    subDomainCode: 'H',
    subDomainName: 'Health',
  ),
  TaxonomyRow(
    subjectCode: 'T',
    subjectName: 'Toys and Tales',
    domainCode: 'T',
    domainName: 'Toys and Tales',
    subDomainCode: 'R',
    subDomainName: 'Transport',
  ),

  TaxonomyRow(
    subjectCode: 'S',
    subjectName: 'Science',
    domainCode: 'Z',
    domainName: 'Partners',
    subDomainCode: 'P',
    subDomainName: 'Physics',
  ),
];

/// Where a resolved categorisation's names actually came from.
///
/// Worth surfacing rather than hiding, because [CategorisationSource.stored]
/// means the code was unknown to the table and the names carry whatever the
/// document happened to hold, [BA05][LearningUnitTaxonomy.resolve] included.
enum CategorisationSource {
  /// Derived from the code through the table. Trustworthy.
  derived,

  /// The code was missing or unknown, so the document's own names were used.
  stored,

  /// Neither a usable code nor usable stored names.
  none,
}

/// A unit's subject, domain and sub-domain, however they were arrived at.
class LearningUnitCategorisation {
  const LearningUnitCategorisation({
    required this.source,
    this.subjectCode,
    this.subjectName,
    this.domainCode,
    this.domainName,
    this.subDomainCode,
    this.subDomainName,
  });

  static const LearningUnitCategorisation unknown = LearningUnitCategorisation(
    source: CategorisationSource.none,
  );

  final CategorisationSource source;
  final String? subjectCode;
  final String? subjectName;
  final String? domainCode;
  final String? domainName;
  final String? subDomainCode;
  final String? subDomainName;

  bool get isKnown => source != CategorisationSource.none;

  /// The two letters, when both are known.
  String? get compositeCode {
    final d = domainCode, s = subDomainCode;
    if (d == null || d.isEmpty || s == null || s.isEmpty) return null;
    return '$d$s';
  }
}

/// The lookup table, with the rows it was built from.
///
/// Held as an instance rather than only as top-level functions so the Firestore
/// copy can replace the static rows wholesale at startup without every caller
/// learning where the rows came from.
class LearningUnitTaxonomy {
  const LearningUnitTaxonomy(this.rows);

  final List<TaxonomyRow> rows;

  /// `Configuration/learningUnitDomains`, field `domains`: the seeded copy of
  /// these rows, and the one a console edit changes.
  static const String configurationCollection = 'Configuration';
  static const String configurationDocId = 'learningUnitDomains';
  static const String domainsField = 'domains';

  /// The static 44.
  static const LearningUnitTaxonomy static_ = LearningUnitTaxonomy(
    kLearningUnitTaxonomy,
  );

  static LearningUnitTaxonomy _default = static_;

  /// What [LearningUnit.categorisation] and other unparameterised callers use.
  ///
  /// Starts as [static_], so every lookup works with Firestore unreachable —
  /// the same fallback discipline the web app applies to its own dropdowns.
  static LearningUnitTaxonomy get instance => _default;

  /// Swap in rows read from `Configuration/learningUnitDomains`.
  ///
  /// A console edit to that document is meant to win at runtime, which is the
  /// entire reason the collection is read at all. An empty or all-blank list is
  /// IGNORED rather than installed: a failed or half-written read must not
  /// leave the app with no vocabulary when it already has 44 good rows.
  static bool replaceDefault(List<TaxonomyRow> rows) {
    final usable = rows
        .where((r) => r.domainCode.isNotEmpty && r.subDomainCode.isNotEmpty)
        .toList(growable: false);
    if (usable.isEmpty) return false;
    _default = LearningUnitTaxonomy(usable);
    return true;
  }

  /// Restore the static rows. For tests, and for signing out of nothing.
  static void resetDefault() => _default = static_;

  /// The row for a code, or null when the code is malformed or its letter pair
  /// has no row.
  ///
  /// The first character is the domain and the second the sub-domain; the two
  /// digits are ignored. A pair with no row is precisely what makes a code
  /// invalid in the web app's authoring form.
  TaxonomyRow? rowForCode(String? code) {
    final trimmed = code?.trim().toUpperCase();
    if (trimmed == null || !kLearningUnitCodePattern.hasMatch(trimmed)) {
      return null;
    }
    final domainCode = trimmed[0];
    final subDomainCode = trimmed[1];
    for (final row in rows) {
      if (row.domainCode == domainCode && row.subDomainCode == subDomainCode) {
        return row;
      }
    }
    return null;
  }

  /// Whether a code is well-formed AND its pair is in the table.
  bool isKnownCode(String? code) => rowForCode(code) != null;

  /// Derive the categorisation from [code], falling back to what the document
  /// stored.
  ///
  /// DERIVE FIRST. This is the whole point of the class. `BA05` stores
  /// `subDomainCode: 'E'` in production while its code says `A`; deriving gives
  /// the sub-domain the code names and ignores the contradicting field. Trusting
  /// the document first would repair the absent and empty cases and faithfully
  /// reproduce the wrong ones.
  ///
  /// The fallback is per-field, not all-or-nothing: an unknown code still lets
  /// a document's own `subjectName` through, because a name that exists beats no
  /// name at all. Blank strings are treated as absent throughout, since
  /// production writes `''` about as often as it omits the field.
  LearningUnitCategorisation resolve({
    String? code,
    String? storedSubjectCode,
    String? storedSubjectName,
    String? storedDomainCode,
    String? storedDomainName,
    String? storedSubDomainCode,
    String? storedSubDomainName,
  }) {
    String? clean(String? value) {
      final trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }

    final row = rowForCode(code);
    if (row != null) {
      // THE TABLE ITSELF HAS A HOLE. Row `SM` carries `domainName: ''` in
      // production's own Configuration document, and the web app copied it in
      // verbatim rather than inventing a name. So a matched row is not a
      // guarantee of a full row, and a blank cell here must still defer to
      // whatever the document stored instead of blanking a name the caller
      // already had. The CODES are safe: rowForCode matched on them.
      return LearningUnitCategorisation(
        source: CategorisationSource.derived,
        subjectCode: clean(row.subjectCode) ?? clean(storedSubjectCode),
        subjectName: clean(row.subjectName) ?? clean(storedSubjectName),
        domainCode: row.domainCode,
        domainName: clean(row.domainName) ?? clean(storedDomainName),
        subDomainCode: row.subDomainCode,
        subDomainName: clean(row.subDomainName) ?? clean(storedSubDomainName),
      );
    }

    // No usable code. Fall back to whatever the document holds, field by field.
    final trimmedCode = clean(code)?.toUpperCase();
    final wellFormed =
        trimmedCode != null && kLearningUnitCodePattern.hasMatch(trimmedCode);

    final fallback = LearningUnitCategorisation(
      source: CategorisationSource.stored,
      subjectCode: clean(storedSubjectCode),
      subjectName: clean(storedSubjectName),
      // A well-formed code whose pair is simply absent from the table still
      // names its own domain and sub-domain letters, and those two characters
      // are better evidence than a field that may contradict them.
      domainCode: wellFormed ? trimmedCode[0] : clean(storedDomainCode),
      domainName: clean(storedDomainName),
      subDomainCode: wellFormed ? trimmedCode[1] : clean(storedSubDomainCode),
      subDomainName: clean(storedSubDomainName),
    );

    final anything =
        fallback.subjectCode ??
        fallback.subjectName ??
        fallback.domainCode ??
        fallback.domainName ??
        fallback.subDomainCode ??
        fallback.subDomainName;

    return anything == null ? LearningUnitCategorisation.unknown : fallback;
  }
}
