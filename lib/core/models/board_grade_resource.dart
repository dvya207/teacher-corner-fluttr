import '../utils/safe_parse.dart';

/// The board-and-grade copy of one grade-dependent resource slot.
///
/// THE THIRD STORE, and the one that made the Pre-Test tab look empty while a
/// PDF was sitting in it. The chain is three documents deep:
///
///   learningUnitResources/{doc}.resources['3S']['conceptPreTestQuizPdf']
///       = { universalGradeBoardResourcePath: '', CBSE: 's9qKMMiIrTMVaay3Kn14' }
///                                                   ^^^^^^^^^^^^^^^^^^^^^^
///                                                   a DOCUMENT ID, not a file
///   boardGradeResources/s9qKMMiIrTMVaay3Kn14.resources
///       = { grade_01: 'learningUnits/…/GradeDependentResources/Sample.pdf' }
///                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
///                      the file, at last
///
/// Reading the board key as if it were a path is what this app did, so the
/// pane was handed 's9qKMMiIrTMVaay3Kn14' and correctly reported that it was
/// not a file. It was a signpost, and nobody followed it.
///
/// WHICH SLOTS ARE LIKE THIS IS READ FROM THE SHAPE, not from a schema. A
/// grade-dependent slot stores a MAP (board keys plus the universal one) and
/// every other slot stores a STRING. The web app made the same call for the
/// same reason: production looks the flag up in `Configuration/resourceNames`
/// via a type-name mapping, while the stored shape already answers it and
/// cannot disagree with the value being read.
class BoardGradeResource {
  const BoardGradeResource({
    required this.docId,
    this.learningUnitDocId,
    this.category,
    this.subCategory,
    this.board,
    this.maturity,
    this.byGrade = const {},
  });

  static const String collection = 'boardGradeResources';

  /// The field these are queried by, one query per learning unit.
  static const String unitField = 'learningUnitDocId';

  /// The id a resource slot's board key points at.
  final String docId;

  final String? learningUnitDocId;

  /// Which slot this is the board copy of. Carried for diagnosis rather than
  /// for lookup: the slot finds this document by id, not by searching.
  final String? category;
  final String? subCategory;

  final String? board;
  final String? maturity;

  /// `grade_04` to a Storage path. Empty entries dropped at parse time.
  final Map<String, String> byGrade;

  /// The file for one grade, or null when this board copy has nothing for it.
  ///
  /// Null rather than falling back to another grade. A grade-3 worksheet is
  /// not the grade-7 one, and showing a teacher the wrong year's paper is
  /// worse than showing them none: they would run the lesson on it.
  String? pathForGrade(String? gradeKey) {
    final key = gradeKey?.trim();
    if (key == null || key.isEmpty) return null;
    final path = byGrade[key];
    return (path == null || path.isEmpty) ? null : path;
  }

  /// The key a grade is stored under, or '' when the grade does not map to one.
  ///
  /// PRODUCTION'S FORMAT, zero-padded to two digits: grade 4 is `grade_04`,
  /// never `grade_4`. Pre-primary years have their own shape. Anything else,
  /// including the "ET" this data also holds, has no key and therefore no
  /// board copy, which is a normal state rather than an error.
  static String gradeKey(Object? grade) {
    final text = grade?.toString().trim() ?? '';
    if (text.isEmpty) return '';

    if (RegExp(r'^\d+$').hasMatch(text)) {
      return 'grade_${text.padLeft(2, '0')}';
    }

    final preprimary = RegExp(
      r'^pre[\s-]*primary\s*(\d+)$',
      caseSensitive: false,
    ).firstMatch(text);
    return preprimary == null ? '' : 'grade_preprimary_${preprimary.group(1)}';
  }

  factory BoardGradeResource.fromMap(String docId, Map<String, dynamic> data) {
    final raw = SafeParse.asStringKeyedMap(
      data['resources'],
      collection: collection,
      docId: docId,
      field: 'resources',
    );

    final byGrade = <String, String>{};
    raw.forEach((grade, value) {
      if (value is String && value.trim().isNotEmpty) {
        byGrade[grade] = value.trim();
      }
    });

    return BoardGradeResource(
      docId: docId,
      learningUnitDocId: SafeParse.asDisplayString(data[unitField]),
      category: SafeParse.asDisplayString(data['category']),
      subCategory: SafeParse.asDisplayString(data['subCategory']),
      board: SafeParse.asDisplayString(data['board']),
      maturity: SafeParse.asDisplayString(data['maturity']),
      byGrade: Map.unmodifiable(byGrade),
    );
  }
}
