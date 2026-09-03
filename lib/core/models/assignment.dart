import '../utils/safe_parse.dart';

/// `Assignments/{docId}` — a quiz, an upload or a form a classroom can be set.
///
/// CAPITALISED COLLECTION, matching production and the web app. The other
/// collections this app reads are lowercase; this one is not, and the difference
/// is deliberate rather than an oversight — it was new when the web app added it,
/// so it could start on production's own name where `learningUnits` and
/// `workflows` would need a data move to get there.
class Assignment {
  const Assignment({
    required this.docId,
    required this.displayName,
    required this.type,
    this.status = '',
    this.creator = '',
    this.author = '',
    this.instructions = '',
    this.allowedSubmissions = 1,
    this.displayCorrectAnswers = false,
    this.allowExitAndReEntry = false,
    this.totalMinutes = 0,
    this.questions = const [],
    this.dueDate,
  });

  final String docId;
  final String displayName;

  /// `QUIZ`, `UPLOAD` or `FORM`, uppercase as production writes it.
  final String type;
  final String status;
  final String creator;
  final String author;

  /// FORM only. Quizzes carry their preamble in `backgroundInfo` instead.
  final String instructions;

  /// `numberOfAllowedSubmissions`. The cap the summary's `attemptsCount` is
  /// checked against, and it spans the whole classroom and programme rather than
  /// this one quiz — production's own choice, copied by the web app.
  final int allowedSubmissions;

  /// Whether the result screen may reveal which options were right.
  final bool displayCorrectAnswers;
  final bool allowExitAndReEntry;

  /// The three duration fields folded into one number.
  final int totalMinutes;

  /// QUIZ only, and read from `questionsData`. See [fromMap].
  final List<QuizQuestion> questions;

  /// Set by the PROGRAMME that allots the assignment, not by the assignment.
  final DateTime? dueDate;

  static const String collection = 'Assignments';

  /// Ids in `Assignments` that are NOT assignments.
  ///
  /// Production's own reference documents. `--schema--` describes the shape and
  /// `--default_assignments--` is a template holder; neither is a row, and both
  /// are present in this database today.
  static const List<String> reservedIds = [
    '--trash--',
    '--schema--',
    '---quizzer_schema---',
    '--default_assignments--',
  ];

  bool get isQuiz => type.toUpperCase() == 'QUIZ';
  bool get isLive => status.trim().toUpperCase() == 'LIVE';

  /// Total marks available, which is the sum the scorer computes as `maxScore`.
  int get totalMarks => questions.fold(0, (sum, q) => sum + q.maxMarks);

  factory Assignment.fromMap(
    String docId,
    Map<String, dynamic> data, {
    DateTime? dueDate,
  }) {
    /*
     * A QUIZ'S QUESTIONS ARE ON `questionsData`, NOT `questions`.
     *
     * Verified against the live collection rather than assumed: every QUIZ
     * document carries `questionsData` and has no `questions` field at all,
     * while every FORM carries `questions` and no `questionsData`. Reading
     * `questions` for a quiz is the obvious guess and yields an empty player
     * with no error to explain it.
     */
    final rawQuestions = data['questionsData'];
    final questions = <QuizQuestion>[];

    if (rawQuestions is List) {
      for (final entry in rawQuestions) {
        if (entry is Map) {
          questions.add(
            QuizQuestion.fromMap(
              entry.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }
      }
    }

    int minutes(String key) =>
        SafeParse.asIntOrNull(
          data[key],
          collection: collection,
          docId: docId,
          field: key,
        ) ??
        0;

    return Assignment(
      docId: docId,
      displayName: SafeParse.asDisplayString(data['displayName']) ?? docId,
      type: (SafeParse.asDisplayString(data['type']) ?? '').toUpperCase(),
      status: SafeParse.asDisplayString(data['status']) ?? '',
      creator: SafeParse.asDisplayString(data['creator']) ?? '',
      author: SafeParse.asDisplayString(data['author']) ?? '',
      instructions: SafeParse.asDisplayString(data['instructions']) ?? '',
      // DEFAULTS TO 1, not 0: a missing cap must not read as "no attempts
      // allowed" and lock every teacher out of a quiz.
      allowedSubmissions:
          SafeParse.asIntOrNull(
            data['numberOfAllowedSubmissions'],
            collection: collection,
            docId: docId,
            field: 'numberOfAllowedSubmissions',
          ) ??
          1,
      displayCorrectAnswers: SafeParse.asBool(data['displayCorrectAnswers']),
      allowExitAndReEntry: SafeParse.asBool(data['allowExitAndReEntry']),
      totalMinutes:
          minutes('totalDurationInHours') * 60 +
          minutes('totalDurationInMinutes'),
      questions: List.unmodifiable(questions),
      dueDate: dueDate,
    );
  }
}

/// One option on an MCQ, a sub-part or a blank.
class AssignmentOption {
  const AssignmentOption({
    required this.name,
    required this.isCorrect,
    this.optionType = 'TEXT',
    this.imagePath = '',
  });

  final String name;
  final bool isCorrect;

  /// `TEXT` or `IMAGE`. An IMAGE option carries its picture in [imagePath] and
  /// usually has an empty [name].
  final String optionType;

  /// A Cloud Storage PATH, not a URL — the same rule as everywhere else here.
  final String imagePath;

  bool get isImage => optionType.toUpperCase() == 'IMAGE';

  factory AssignmentOption.fromMap(Map<String, dynamic> data) =>
      AssignmentOption(
        name: SafeParse.asDisplayString(data['name']) ?? '',
        isCorrect: SafeParse.asBool(data['isCorrect']),
        optionType: SafeParse.asDisplayString(data['optionType']) ?? 'TEXT',
        imagePath: SafeParse.asDisplayString(data['imagePath']) ?? '',
      );
}

/// A question that is split into lettered parts, each marked on its own.
class QuizSubPart {
  const QuizSubPart({
    required this.label,
    required this.marks,
    this.subPartTitle = '',
    this.options = const [],
    this.oneCorrectOption = false,
  });

  final String label;
  final int marks;
  final String subPartTitle;
  final List<AssignmentOption> options;
  final bool oneCorrectOption;

  factory QuizSubPart.fromMap(Map<String, dynamic> data) => QuizSubPart(
    label: SafeParse.asDisplayString(data['label']) ?? '',
    // ONE, not zero, where the field is missing. The scorer uses
    // `subPart.marks || 1`, and a sub-part worth nothing is not a thing
    // production models.
    marks: SafeParse.asIntOrNull(data['marks']) ?? 1,
    subPartTitle: SafeParse.asDisplayString(data['subPartTitle']) ?? '',
    options: _options(data['options']),
    oneCorrectOption: SafeParse.asBool(data['oneCorrectOption']),
  );
}

/// One question of a quiz.
class QuizQuestion {
  const QuizQuestion({
    required this.questionTitle,
    required this.questionType,
    required this.marks,
    this.pedagogyType = 'FA',
    this.hasSubParts = false,
    this.subParts = const [],
    this.options = const [],
    this.oneCorrectOption = false,
    this.answer = '',
    this.maxCharLength = 0,
    this.blanks = const {},
    this.durationMinutes = 0,
  });

  /// HTML from a rich-text editor, not plain text.
  final String questionTitle;

  /// `MCQ`, `TEXT`, `FILL_IN_THE_BLANKS`, `RICH_BLANKS`, `DESCRIPTIVE`.
  final String questionType;
  final int marks;
  final String pedagogyType;

  final bool hasSubParts;
  final List<QuizSubPart> subParts;

  /// MCQ only.
  final List<AssignmentOption> options;

  /// Whether exactly one option is right. NOT enforced by the scorer — see
  /// `exactlyCorrect`, which compares the whole option list either way.
  final bool oneCorrectOption;

  /// TEXT only. The model answer, which the scorer deliberately ignores.
  final String answer;
  final int maxCharLength;

  /// Both blank types. Keyed by blank label, e.g. `optionsBlank1`.
  final Map<String, List<AssignmentOption>> blanks;

  final int durationMinutes;

  bool get isMcq => questionType.toUpperCase() == 'MCQ';
  bool get isText => questionType.toUpperCase() == 'TEXT';

  bool get isBlanks {
    final type = questionType.toUpperCase();
    return type == 'FILL_IN_THE_BLANKS' || type == 'RICH_BLANKS';
  }

  bool get usesSubParts => hasSubParts && subParts.isNotEmpty;

  /// What this question contributes to `maxScore`.
  ///
  /// A QUESTION WITH SUB-PARTS IGNORES ITS OWN `marks` ENTIRELY and is worth the
  /// sum of its parts. That is production's rule and the scorer's, and it is the
  /// kind of thing a reader would "fix" without knowing where it came from.
  int get maxMarks =>
      usesSubParts ? subParts.fold(0, (sum, p) => sum + p.marks) : marks;

  factory QuizQuestion.fromMap(Map<String, dynamic> data) {
    final rawBlanks = data['blanks'];
    final blanks = <String, List<AssignmentOption>>{};

    if (rawBlanks is Map) {
      rawBlanks.forEach((key, value) {
        blanks[key.toString()] = _options(value);
      });
    }

    final rawSubParts = data['subParts'];
    final subParts = <QuizSubPart>[];

    if (rawSubParts is List) {
      for (final entry in rawSubParts) {
        if (entry is Map) {
          subParts.add(
            QuizSubPart.fromMap(entry.map((k, v) => MapEntry(k.toString(), v))),
          );
        }
      }
    }

    return QuizQuestion(
      questionTitle: SafeParse.asDisplayString(data['questionTitle']) ?? '',
      questionType: (SafeParse.asDisplayString(data['questionType']) ?? '')
          .toUpperCase(),
      marks: SafeParse.asIntOrNull(data['marks']) ?? 0,
      pedagogyType: SafeParse.asDisplayString(data['pedagogyType']) ?? 'FA',
      hasSubParts: SafeParse.asBool(data['hasSubParts']),
      subParts: List.unmodifiable(subParts),
      options: _options(data['options']),
      oneCorrectOption: SafeParse.asBool(data['oneCorrectOption']),
      answer: SafeParse.asDisplayString(data['answer']) ?? '',
      maxCharLength: SafeParse.asIntOrNull(data['maxCharLength']) ?? 0,
      blanks: Map.unmodifiable(blanks),
      durationMinutes:
          (SafeParse.asIntOrNull(data['durationInHours']) ?? 0) * 60 +
          (SafeParse.asIntOrNull(data['durationInMinutes']) ?? 0),
    );
  }
}

List<AssignmentOption> _options(dynamic raw) {
  if (raw is! List) return const [];

  final out = <AssignmentOption>[];

  for (final entry in raw) {
    if (entry is Map) {
      out.add(
        AssignmentOption.fromMap(
          entry.map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
    }
  }

  return List.unmodifiable(out);
}
