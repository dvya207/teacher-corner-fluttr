import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/assignment.dart';
import 'package:tc_starter/core/models/quiz_scoring.dart';

/// Marking an attempt.
///
/// WHAT IS WORTH TESTING HERE IS THE ARITHMETIC, and it is worth testing because
/// it is COPIED rather than designed. A score written into the same collection
/// the web app reads has to be computed the way the web app computes it, and its
/// rules are not the ones anybody would guess. Each of these is a line a
/// reasonable person would "fix" on sight.
QuizQuestion mcq({required List<bool> correct, int marks = 1}) => QuizQuestion(
  questionTitle: 'q',
  questionType: 'MCQ',
  marks: marks,
  options: [
    for (var i = 0; i < correct.length; i++)
      AssignmentOption(name: 'opt$i', isCorrect: correct[i]),
  ],
);

void main() {
  group('an MCQ is all-or-nothing on EVERY option', () {
    test('scores only when the chosen set matches exactly', () {
      final q = [
        mcq(correct: [true, false, true], marks: 2),
      ];

      expect(
        attemptMarks(q, [
          const QuizAnswer(chosen: [0, 2]),
        ]).studentScore,
        2,
      );
    });

    test('missing a correct option scores zero, not partial', () {
      final q = [
        mcq(correct: [true, false, true], marks: 2),
      ];

      expect(
        attemptMarks(q, [
          const QuizAnswer(chosen: [0]),
        ]).studentScore,
        0,
      );
    });

    test('adding a wrong option scores zero', () {
      final q = [
        mcq(correct: [true, false, true], marks: 2),
      ];

      expect(
        attemptMarks(q, [
          const QuizAnswer(chosen: [0, 1, 2]),
        ]).studentScore,
        0,
      );
    });

    test('ticking everything does NOT score', () {
      // The reason exactlyCorrect compares the whole list rather than checking
      // that the correct ones are present.
      final q = [
        mcq(correct: [true, false, false]),
      ];

      expect(
        attemptMarks(q, [
          const QuizAnswer(chosen: [0, 1, 2]),
        ]).studentScore,
        0,
      );
    });

    test('a question with no correct option can never be right', () {
      // Otherwise choosing nothing would score full marks on a broken question.
      final q = [
        mcq(correct: [false, false]),
      ];

      expect(attemptMarks(q, [const QuizAnswer()]).studentScore, 0);
      expect(
        attemptMarks(q, [
          const QuizAnswer(chosen: [0, 1]),
        ]).studentScore,
        0,
      );
    });
  });

  group('a TEXT question scores full for ANY non-empty answer', () {
    final q = [
      const QuizQuestion(
        questionTitle: 'q',
        questionType: 'TEXT',
        marks: 5,
        answer: 'the model answer nobody reads',
      ),
    ];

    test('anything at all scores full marks', () {
      // Production's rule, and emphatically not a slip: the stored answer is
      // never compared against.
      expect(
        attemptMarks(q, [const QuizAnswer(text: 'nonsense')]).studentScore,
        5,
      );
    });

    test('blank and whitespace-only score zero', () {
      expect(attemptMarks(q, [const QuizAnswer(text: '')]).studentScore, 0);
      expect(attemptMarks(q, [const QuizAnswer(text: '   ')]).studentScore, 0);
    });
  });

  group('blanks score partial credit', () {
    QuizQuestion blanks(int marks) => QuizQuestion(
      questionTitle: 'q',
      questionType: 'FILL_IN_THE_BLANKS',
      marks: marks,
      blanks: {
        'optionsBlank1': [const AssignmentOption(name: 'red', isCorrect: true)],
        'optionsBlank2': [
          const AssignmentOption(name: 'blue', isCorrect: true),
        ],
        'optionsBlank3': [
          const AssignmentOption(name: 'green', isCorrect: true),
        ],
      },
    );

    test('all three right scores full', () {
      final marks = attemptMarks(
        [blanks(3)],
        [
          const QuizAnswer(
            blanks: {
              'optionsBlank1': 'red',
              'optionsBlank2': 'blue',
              'optionsBlank3': 'green',
            },
          ),
        ],
      );

      expect(marks.studentScore, 3);
    });

    test('one of three on two marks rounds to 0.67', () {
      // The exact figure the web app's comment cites.
      final marks = attemptMarks(
        [blanks(2)],
        [
          const QuizAnswer(blanks: {'optionsBlank1': 'red'}),
        ],
      );

      expect(marks.studentScore, 0.67);
    });

    test('matching is case-folded and trimmed', () {
      final marks = attemptMarks(
        [blanks(3)],
        [
          const QuizAnswer(blanks: {'optionsBlank1': '  RED  '}),
        ],
      );

      expect(marks.studentScore, 1);
    });

    test('a wrong word scores nothing for that blank', () {
      final marks = attemptMarks(
        [blanks(3)],
        [
          const QuizAnswer(blanks: {'optionsBlank1': 'purple'}),
        ],
      );

      expect(marks.studentScore, 0);
    });
  });

  group('sub-parts', () {
    final question = QuizQuestion(
      questionTitle: 'q',
      questionType: 'MCQ',
      // IGNORED ENTIRELY when sub-parts exist. Deliberately large so a
      // regression that counted it would be obvious.
      marks: 99,
      hasSubParts: true,
      subParts: [
        QuizSubPart(
          label: 'a',
          marks: 2,
          options: const [
            AssignmentOption(name: 'yes', isCorrect: true),
            AssignmentOption(name: 'no', isCorrect: false),
          ],
        ),
        QuizSubPart(
          label: 'b',
          marks: 3,
          options: const [
            AssignmentOption(name: 'yes', isCorrect: true),
            AssignmentOption(name: 'no', isCorrect: false),
          ],
        ),
      ],
    );

    test('the question is worth the SUM OF ITS PARTS, not its own marks', () {
      final marks = attemptMarks([question], [const QuizAnswer()]);

      expect(marks.maxScore, 5, reason: 'not 99');
    });

    test('each part is marked on its own', () {
      final marks = attemptMarks(
        [question],
        [
          const QuizAnswer(
            subParts: [
              [0],
              [1],
            ],
          ),
        ],
      );

      expect(marks.studentScore, 2, reason: 'a right, b wrong');
    });
  });

  group('the maximum', () {
    test('counts unmarkable questions too', () {
      // DESCRIPTIVE scores nothing but still raises the total, so a percentage
      // is out of everything the quiz was worth.
      final marks = attemptMarks(
        [
          const QuizQuestion(
            questionTitle: 'q',
            questionType: 'DESCRIPTIVE',
            marks: 4,
          ),
        ],
        [const QuizAnswer(text: 'an essay')],
      );

      expect(marks.maxScore, 4);
      expect(marks.studentScore, 0);
    });

    test('a missing answer is treated as unanswered, not as a crash', () {
      // The player can hold fewer answers than there are questions.
      final marks = attemptMarks([
        mcq(correct: [true]),
        mcq(correct: [true]),
      ], []);

      expect(marks.maxScore, 2);
      expect(marks.studentScore, 0);
    });
  });

  group('attemptPercentage', () {
    test('rounds', () {
      expect(
        attemptPercentage(const AttemptMarks(studentScore: 1, maxScore: 3)),
        33,
      );
    });

    test('is null when nothing was markable, rather than zero', () {
      // Told apart from a genuine 0%, which is a real result.
      expect(
        attemptPercentage(const AttemptMarks(studentScore: 0, maxScore: 0)),
        isNull,
      );
    });
  });
}
