import 'assignment.dart';
import 'form_question.dart';
import 'learning_unit.dart';
import '../utils/safe_parse.dart';

/// What kind of thing a teacher did, as one block of their submission.
///
/// THE BLOCKS ARE THE UNIT OF DISPLAY, not the assignment. One activity can
/// carry a readiness form, a photo upload, an observation form and a quiz, and
/// a teacher reading their own record wants them in the order they happened
/// rather than grouped by a type name they never see.
enum SubmissionBlockKind {
  /// A questionnaire: questions and the answers given.
  form,

  /// Photographs, or a file, handed in against an upload assignment.
  upload,

  /// A quiz attempt, with its score.
  quiz,
}

/// One question and what was answered, already flattened for display.
///
/// THE ANSWER IS A STRING BY THE TIME IT IS HERE, and that is deliberate.
/// Stored answers are a mess of shapes, all of them real in
/// `users/{uid}/formResponses`:
///
///     "1": ["very easy"]                  a single choice, in a list
///     "2": ["yes", "partially"]           several choices
///     "5": "nothing"                      free text
///     "6": 3                              a number
///
/// A widget that had to branch on all four would branch on all four in every
/// place it rendered one. The flattening happens once, here.
class SubmissionAnswer {
  const SubmissionAnswer({required this.question, required this.answer});

  /// The question as the teacher was asked it, or its number where the
  /// assignment could not be read. NEVER the stored key alone: "1" tells a
  /// teacher nothing about what they answered.
  final String question;

  /// Empty when the question was left unanswered, which the sheet shows as a
  /// dash rather than as a blank line.
  final String answer;

  bool get isAnswered => answer.trim().isNotEmpty;
}

/// A quiz attempt's outcome.
class QuizOutcome {
  const QuizOutcome({
    required this.score,
    required this.maxScore,
    required this.attempts,
    this.percentage,
    this.lastAttemptAt,
  });

  final int score;
  final int maxScore;

  /// How many times it was attempted. Shown because an assignment caps
  /// attempts, so "5 / 5 on the third try" is a different fact from "5 / 5".
  final int attempts;

  /// As stored, rather than recomputed. The stored value is what the web app
  /// reports, and a second calculation here could disagree with it over
  /// rounding.
  final double? percentage;

  final DateTime? lastAttemptAt;
}

/// One thing a teacher submitted, of one kind.
class SubmissionBlock {
  const SubmissionBlock({
    required this.kind,
    this.title,
    this.answers = const [],
    this.photoPaths = const [],
    this.quiz,
    this.submittedAt,
  });

  final SubmissionBlockKind kind;

  /// The assignment's own name, which is what the workflow tab was labelled
  /// with. Null where the assignment could not be read.
  final String? title;

  final List<SubmissionAnswer> answers;

  /// Storage paths, NOT download URLs. Resolved at render time by the same
  /// cache-on-path route every other image in this app uses; a stored URL
  /// carries a token that expires.
  final List<String> photoPaths;

  final QuizOutcome? quiz;

  final DateTime? submittedAt;

  /// True when this block holds nothing at all: a form with every question
  /// blank, or an upload with no photos.
  ///
  /// KEPT AND SHOWN ANYWAY. The reference app renders an EVIDENCE block whose
  /// two questions both read "—", and that is the honest thing: the block
  /// exists in the workflow, the teacher reached it, and they answered
  /// nothing. Dropping it would make the record look complete.
  bool get isEmpty =>
      photoPaths.isEmpty &&
      quiz == null &&
      answers.every((a) => !a.isAnswered);
}

/// Everything one teacher did against one learning unit, in one classroom.
class ActivitySubmissions {
  const ActivitySubmissions({
    required this.learningUnitId,
    this.unit,
    this.blocks = const [],
  });

  final String learningUnitId;

  /// Null where the unit document is gone. The activity still lists, named by
  /// its id, because a submission against a deleted unit is still a record of
  /// work done.
  final LearningUnit? unit;

  final List<SubmissionBlock> blocks;

  String get label => unit?.label ?? learningUnitId;

  /// Whether the teacher has handed anything in at all.
  ///
  /// A BLOCK EXISTING IS NOT ENOUGH. The workflow declares the blocks; what
  /// counts is whether any of them has content, which is what the list's
  /// "Not submitted" against a teacher's name means.
  bool get hasAnySubmission => blocks.any((b) => !b.isEmpty);

  int get submittedCount => blocks.where((b) => !b.isEmpty).length;

  int get totalCount => blocks.length;
}

/// Reads the three stored shapes into [SubmissionBlock]s.
///
/// A PARSER RATHER THAN A MODEL CONSTRUCTOR, because the inputs are three
/// separate documents that only mean something together:
///
///   users/{uid}/formResponses/{classroomId}-{assignmentId}   the answers
///   users/{uid}/submissions/{classroomId}-{programmeId}      photos and quizzes
///   Assignments/{assignmentId}                               the question TEXT
///
/// The third is what makes the first legible. Answers are keyed "1", "2", "3",
/// and the questions those numbers refer to live on the assignment.
class SubmissionParser {
  const SubmissionParser._();

  /// The form block for one assignment, or null when nothing was answered and
  /// the assignment has no questions to show as unanswered either.
  static SubmissionBlock? formBlock({
    required Assignment? assignment,
    required Map<String, dynamic>? response,
  }) {
    final questions = assignment?.formQuestions ?? const <FormQuestion>[];
    final rawAnswers = SafeParse.asStringKeyedMap(
      response?['answers'],
      collection: 'formResponses',
      field: 'answers',
    );

    if (questions.isEmpty && rawAnswers.isEmpty) return null;

    final answers = <SubmissionAnswer>[];
    if (questions.isNotEmpty) {
      // QUESTION ORDER WINS over answer order, so an unanswered question keeps
      // its place in the list instead of vanishing from the middle of a form.
      for (final question in questions) {
        answers.add(
          SubmissionAnswer(
            question: question.question,
            answer: _flatten(rawAnswers['${question.number}']),
          ),
        );
      }
    } else {
      // The assignment could not be read. The answers are still worth showing;
      // they are just labelled by number, which is all there is to go on.
      final keys = rawAnswers.keys.toList()
        ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
      for (final key in keys) {
        answers.add(
          SubmissionAnswer(
            question: 'Question $key',
            answer: _flatten(rawAnswers[key]),
          ),
        );
      }
    }

    return SubmissionBlock(
      kind: SubmissionBlockKind.form,
      title: assignment?.displayName,
      answers: answers,
      submittedAt: SafeParse.asDate(response?['submittedAt']),
    );
  }

  /// The upload block for one assignment out of the submissions document.
  static SubmissionBlock? uploadBlock({
    required Assignment? assignment,
    required Map<String, dynamic>? entry,
  }) {
    if (entry == null) return null;

    final paths = <String>[];
    final raw = entry['storagePaths'];
    if (raw is List) {
      for (final value in raw) {
        if (value is String && value.trim().isNotEmpty) paths.add(value.trim());
      }
    }

    return SubmissionBlock(
      kind: SubmissionBlockKind.upload,
      title: SafeParse.asDisplayString(entry['displayName']) ??
          assignment?.displayName,
      photoPaths: paths,
      submittedAt: SafeParse.asDate(entry['submittedAt']),
    );
  }

  /// The quiz block, read off the submissions document's own top level.
  ///
  /// NOT NESTED UNDER AN ASSIGNMENT ID, unlike the uploads, which is worth
  /// stating because the two live in the same document. A quiz attempt is
  /// written as the document's own fields — `assignmentId`, `maxScore`,
  /// `latestAttempt` — so one document holds at most one quiz.
  static SubmissionBlock? quizBlock({
    required Assignment? assignment,
    required Map<String, dynamic>? record,
  }) {
    if (record == null) return null;

    final latest = SafeParse.asStringKeyedMap(
      record['latestAttempt'],
      collection: 'submissions',
      field: 'latestAttempt',
    );
    if (latest.isEmpty) return null;

    final score = SafeParse.asIntOrNull(
      latest['studentScore'],
      collection: 'submissions',
      field: 'latestAttempt.studentScore',
    );
    final maxScore = SafeParse.asIntOrNull(
      latest['maxScore'] ?? record['maxScore'],
      collection: 'submissions',
      field: 'latestAttempt.maxScore',
    );
    if (score == null || maxScore == null) return null;

    final percentage = latest['percentage'];
    return SubmissionBlock(
      kind: SubmissionBlockKind.quiz,
      title: SafeParse.asDisplayString(record['displayName']) ??
          assignment?.displayName,
      quiz: QuizOutcome(
        score: score,
        maxScore: maxScore,
        attempts: SafeParse.asIntOrNull(
              record['attemptsCount'],
              collection: 'submissions',
              field: 'attemptsCount',
            ) ??
            1,
        percentage: percentage is num ? percentage.toDouble() : null,
        lastAttemptAt: SafeParse.asDate(record['lastAttemptTime']),
      ),
      submittedAt: SafeParse.asDate(record['lastAttemptTime']),
    );
  }

  /// One stored answer, whatever shape it arrived in, as a line of text.
  static String _flatten(Object? value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is num || value is bool) return '$value';
    if (value is List) {
      return value
          .map((v) => v == null ? '' : '$v'.trim())
          .where((v) => v.isNotEmpty)
          // COMMA-SEPARATED, matching how the reference app shows a
          // multiple-choice answer: "Materials, Conducting the activity,
          // Managing the classroom" on one line.
          .join(', ');
    }
    if (value is Map) {
      return value.values
          .map((v) => v == null ? '' : '$v'.trim())
          .where((v) => v.isNotEmpty)
          .join(', ');
    }
    return '';
  }
}
