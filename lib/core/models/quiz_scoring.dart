import 'assignment.dart';

/// One question's answer, as the player holds it.
class QuizAnswer {
  const QuizAnswer({
    this.chosen = const [],
    this.text = '',
    this.blanks = const {},
    this.subParts = const [],
  });

  /// Indexes into the question's options.
  final List<int> chosen;

  /// TEXT answers.
  final String text;

  /// Keyed by blank label, holding what the reader typed.
  final Map<String, String> blanks;

  /// Per sub-part chosen option indexes.
  final List<List<int>> subParts;

  QuizAnswer copyWith({
    List<int>? chosen,
    String? text,
    Map<String, String>? blanks,
    List<List<int>>? subParts,
  }) => QuizAnswer(
    chosen: chosen ?? this.chosen,
    text: text ?? this.text,
    blanks: blanks ?? this.blanks,
    subParts: subParts ?? this.subParts,
  );

  bool get isAnswered =>
      chosen.isNotEmpty ||
      text.trim().isNotEmpty ||
      blanks.values.any((v) => v.trim().isNotEmpty) ||
      subParts.any((p) => p.isNotEmpty);
}

/// A marked attempt.
class AttemptMarks {
  const AttemptMarks({required this.studentScore, required this.maxScore});

  final double studentScore;
  final int maxScore;
}

/// Marks an attempt.
///
/// COPIED FROM THE WEB APP'S `attemptMarks`, RULE FOR RULE, and the rules are not
/// the ones anybody would guess. They exist so a score written into the same
/// collection production reads is computed the way production computes it, and
/// each one is a line somebody would "fix" on sight:
///
///   - AN MCQ IS ALL-OR-NOTHING ON EVERY OPTION, not on the ones chosen. Missing
///     a correct option and ticking a wrong one both score zero, and so does
///     ticking every box.
///   - A TEXT QUESTION SCORES FULL MARKS FOR ANY NON-EMPTY ANSWER, without being
///     compared to the stored one. The model answer is never read.
///   - BLANKS SCORE PARTIAL CREDIT, rounded to two decimals.
///   - A QUESTION WITH SUB-PARTS IGNORES ITS OWN `marks` and is worth the sum of
///     its parts.
///   - DESCRIPTIVE and anything unrecognised is not markable and scores zero,
///     while still contributing its marks to the maximum.
///
/// Changing any of them makes this app's stored scores disagree with the web
/// app's for the same attempt.
AttemptMarks attemptMarks(
  List<QuizQuestion> questions,
  List<QuizAnswer> answers,
) {
  var studentScore = 0.0;
  var maxScore = 0;

  for (var at = 0; at < questions.length; at++) {
    final question = questions[at];
    final answer = at < answers.length ? answers[at] : const QuizAnswer();

    if (question.usesSubParts) {
      for (var subAt = 0; subAt < question.subParts.length; subAt++) {
        final subPart = question.subParts[subAt];
        final marks = subPart.marks == 0 ? 1 : subPart.marks;

        maxScore += marks;

        final chosen = subAt < answer.subParts.length
            ? answer.subParts[subAt]
            : const <int>[];

        if (exactlyCorrect(subPart.options, chosen)) {
          studentScore += marks;
        }
      }

      continue;
    }

    final marks = question.marks;

    maxScore += marks;

    if (question.isMcq) {
      if (exactlyCorrect(question.options, answer.chosen)) {
        studentScore += marks;
      }

      continue;
    }

    if (question.isText) {
      // ANY TEXT SCORES FULL. Production's rule, not a slip here.
      if (answer.text.trim().isNotEmpty) {
        studentScore += marks;
      }

      continue;
    }

    if (question.isBlanks) {
      final keys = question.blanks.keys.toList();

      if (keys.isEmpty) continue;

      final correct = keys.where((key) {
        final typed = (answer.blanks[key] ?? '').trim();

        if (typed.isEmpty) return false;

        /*
         * MATCHED AGAINST THE BLANK'S OWN OPTIONS, CASE-FOLDED.
         *
         * Production reads `selectedOption.isCorrect` because its blanks are
         * dropdowns. This player offers a text box, since showing two options in
         * a dropdown gives the answer away, so the typed value is matched against
         * the option list instead. Same verdict for a reader who types the right
         * word, and the web app's player does exactly this.
         */
        return (question.blanks[key] ?? const []).any(
          (option) =>
              option.isCorrect &&
              option.name.trim().toLowerCase() == typed.toLowerCase(),
        );
      }).length;

      final earned = (marks / keys.length) * correct;

      // TWO DECIMALS, as production rounds it: 1 of 3 blanks on 2 marks is 0.67.
      studentScore += earned == earned.roundToDouble()
          ? earned
          : double.parse(earned.toStringAsFixed(2));
    }

    // DESCRIPTIVE and anything unrecognised: not markable, scores 0.
  }

  return AttemptMarks(studentScore: studentScore, maxScore: maxScore);
}

/// Whether the chosen set matches the correct set EXACTLY.
///
/// A question with no options, or none marked correct, can never be right —
/// otherwise choosing nothing would score full marks on a broken question.
bool exactlyCorrect(List<AssignmentOption> options, List<int> chosen) {
  if (options.isEmpty || !options.any((option) => option.isCorrect)) {
    return false;
  }

  for (var at = 0; at < options.length; at++) {
    if (options[at].isCorrect != chosen.contains(at)) return false;
  }

  return true;
}

/// Percentage for display, or null when nothing was markable.
int? attemptPercentage(AttemptMarks marks) {
  if (marks.maxScore <= 0) return null;

  return ((marks.studentScore / marks.maxScore) * 100).round();
}

/// The questions as an ATTEMPT stores them: every option stamped with whether
/// it was chosen, and typed answers folded in.
///
/// PRODUCTION'S STORED SHAPE, and the reason an attempt document is bigger than
/// the answers alone. A reader of a stored attempt gets the question, its
/// options, which were correct AND which the teacher picked, without having to
/// join back to the assignment — which matters because the assignment can be
/// edited after the attempt was made.
///
/// `timeTaken` IS WRITTEN AS NULL on every question. Production has the field and
/// this player does not time individual questions; writing null keeps the shape
/// while being honest that the figure was never measured. A zero would read as
/// "answered instantly".
List<Map<String, dynamic>> stampAnswers(
  List<QuizQuestion> questions,
  List<QuizAnswer> answers,
) {
  final out = <Map<String, dynamic>>[];

  for (var at = 0; at < questions.length; at++) {
    final question = questions[at];
    final answer = at < answers.length ? answers[at] : const QuizAnswer();

    final stamped = <String, dynamic>{
      'questionTitle': question.questionTitle,
      'questionType': question.questionType,
      'marks': question.marks,
      'pedagogyType': question.pedagogyType,
      'hasSubParts': question.hasSubParts,
      'timeTaken': null,
    };

    if (question.options.isNotEmpty) {
      stamped['options'] = [
        for (var i = 0; i < question.options.length; i++)
          _option(question.options[i], answer.chosen.contains(i)),
      ];
      stamped['oneCorrectOption'] = question.oneCorrectOption;
    }

    if (question.subParts.isNotEmpty) {
      stamped['subParts'] = [
        for (var s = 0; s < question.subParts.length; s++)
          {
            'label': question.subParts[s].label,
            'marks': question.subParts[s].marks,
            'subPartTitle': question.subParts[s].subPartTitle,
            'options': [
              for (var i = 0; i < question.subParts[s].options.length; i++)
                _option(
                  question.subParts[s].options[i],
                  s < answer.subParts.length && answer.subParts[s].contains(i),
                ),
            ],
          },
      ];
    }

    if (question.blanks.isNotEmpty) {
      stamped['blanks'] = {
        for (final entry in question.blanks.entries)
          entry.key: [for (final o in entry.value) _option(o, false)],
      };
    }

    /*
     * THE TYPED ANSWERS GO ON THE QUESTION TOO, under names that say what they
     * are. Production stores a text answer as `text`; that is copied exactly. Its
     * blanks are DROPDOWNS and it stores `[blankName].selectedOption`, but this
     * player's blanks are typed, so there is no option object to store and the
     * values go in a `blanksAnswered` map instead. Naming it differently is
     * honest; writing a typed string into a field whose readers expect an option
     * would not be. The web app's player does exactly the same.
     */
    if (answer.text.isNotEmpty) {
      stamped['text'] = answer.text;
    }

    if (answer.blanks.isNotEmpty) {
      stamped['blanksAnswered'] = Map<String, String>.from(answer.blanks);
    }

    out.add(stamped);
  }

  return out;
}

Map<String, dynamic> _option(AssignmentOption option, bool attempted) => {
  'name': option.name,
  'isCorrect': option.isCorrect,
  'optionType': option.optionType,
  'imagePath': option.imagePath,
  'attemptedOption': attempted,
};
