import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/assignment.dart';
import 'package:tc_starter/core/models/quiz_scoring.dart';

/// The parser and scorer, run against the REAL documents.
///
/// WHY A FIXTURE DUMPED FROM THE DATABASE RATHER THAN HAND-WRITTEN MAPS. Every
/// other test here builds its own input, which proves the code does what the
/// test author believed the data looks like. That is exactly the assumption that
/// was already wrong twice on this feature: a quiz's questions turned out to be
/// on `questionsData` rather than `questions`, and a programme's `assignmentIds`
/// turned out to be a map rather than a list. Neither hand-written fixture would
/// have caught either.
///
/// `test/assets/real_quizzes.json` is the four QUIZ documents in
/// teacher-corner-dev, copied verbatim. Refresh it by re-dumping the collection.
void main() {
  final raw =
      jsonDecode(File('test/assets/real_quizzes.json').readAsStringSync())
          as Map<String, dynamic>;

  Assignment parse(String id) =>
      Assignment.fromMap(id, raw[id] as Map<String, dynamic>);

  test('the fixture is the real thing, not an empty file', () {
    expect(raw, hasLength(4));
  });

  group('every real quiz parses', () {
    test('and none loses its questions', () {
      // The failure this catches: reading `questions` instead of
      // `questionsData` yields an empty player and no error at all.
      for (final id in raw.keys) {
        final quiz = parse(id);

        expect(quiz.isQuiz, isTrue, reason: id);
        expect(
          quiz.questions,
          isNotEmpty,
          reason: '$id "${quiz.displayName}" parsed with no questions',
        );
      }
    });

    test('no question loses its type', () {
      for (final id in raw.keys) {
        for (final question in parse(id).questions) {
          expect(question.questionType, isNotEmpty, reason: id);
        }
      }
    });
  });

  group('LA LA — five MCQs', () {
    final quiz = parse('QgBPyT8Pq0wFEbhaSiMQ');

    test('reads its options and its correct answers', () {
      expect(quiz.questions, hasLength(5));

      final first = quiz.questions.first;

      expect(first.isMcq, isTrue);
      expect(first.options, isNotEmpty);
      expect(
        first.options.any((o) => o.isCorrect),
        isTrue,
        reason: 'a question with no correct option can never be scored',
      );
    });

    test('answering every question correctly scores full marks', () {
      final answers = [
        for (final q in quiz.questions)
          QuizAnswer(
            chosen: [
              for (var i = 0; i < q.options.length; i++)
                if (q.options[i].isCorrect) i,
            ],
          ),
      ];

      final marks = attemptMarks(quiz.questions, answers);

      expect(marks.maxScore, quiz.totalMarks);
      expect(marks.studentScore, marks.maxScore.toDouble());
      expect(attemptPercentage(marks), 100);
    });

    test('answering nothing scores zero out of the same maximum', () {
      final marks = attemptMarks(quiz.questions, [
        for (final _ in quiz.questions) const QuizAnswer(),
      ]);

      expect(marks.studentScore, 0);
      expect(marks.maxScore, greaterThan(0));
    });
  });

  group('test4 — every question type in one quiz', () {
    final quiz = parse('OilcCZPh4gF9fJ5PCApl');

    test('carries MCQ, blanks, text, rich blanks and descriptive', () {
      expect(quiz.questions.map((q) => q.questionType), [
        'MCQ',
        'FILL_IN_THE_BLANKS',
        'TEXT',
        'RICH_BLANKS',
        'DESCRIPTIVE',
      ]);
    });

    test(
      'RICH_BLANKS is treated as a blanks question, not as unrecognised',
      () {
        final rich = quiz.questions[3];

        expect(rich.isBlanks, isTrue);
      },
    );

    test('DESCRIPTIVE contributes to the maximum but can never be scored', () {
      final descriptive = quiz.questions[4];
      final marks = attemptMarks(
        [descriptive],
        [const QuizAnswer(text: 'an essay')],
      );

      expect(marks.maxScore, descriptive.marks);
      expect(marks.studentScore, 0);
    });

    test('the whole quiz stamps without throwing on any type', () {
      // stampAnswers touches options, subParts and blanks; a type it mishandles
      // shows up here rather than at submit time.
      final stamped = stampAnswers(quiz.questions, [
        for (final _ in quiz.questions) const QuizAnswer(),
      ]);

      expect(stamped, hasLength(quiz.questions.length));
      expect(stamped.every((q) => q.containsKey('timeTaken')), isTrue);
    });
  });

  group('MY QUIZ — blanks only', () {
    final quiz = parse('CG7spdTtfvTifgdp6bCR');

    test('reads the blanks map off the real document', () {
      final first = quiz.questions.first;

      expect(first.isBlanks, isTrue);
      expect(first.blanks, isNotEmpty);
      expect(first.blanks.values.first, isNotEmpty);
    });

    test('typing the stored correct option scores the blank', () {
      final first = quiz.questions.first;
      final key = first.blanks.keys.first;
      final correct = first.blanks[key]!
          .firstWhere((option) => option.isCorrect)
          .name;

      final marks = attemptMarks(
        [first],
        [
          QuizAnswer(blanks: {key: correct}),
        ],
      );

      expect(marks.studentScore, greaterThan(0));
    });
  });

  group('MEOW — one TEXT question', () {
    final quiz = parse('DHJ97HziClo5jeIVdPqI');

    test('any non-empty answer scores full, ignoring the model answer', () {
      final question = quiz.questions.single;

      expect(question.answer, isNotEmpty, reason: 'the model answer exists');

      final marks = attemptMarks(
        [question],
        [const QuizAnswer(text: 'completely unrelated')],
      );

      expect(marks.studentScore, question.marks.toDouble());
    });
  });

  test('every real quiz allows at least one submission', () {
    // A missing numberOfAllowedSubmissions defaulting to 0 would lock every
    // teacher out of every quiz, silently.
    for (final id in raw.keys) {
      expect(parse(id).allowedSubmissions, greaterThan(0), reason: id);
    }
  });

  /// DESCRIPTIVE is ANSWERABLE, even though it is not auto-marked.
  ///
  /// The player first showed "this cannot be answered here" for it, conflating
  /// two different things: the scorer gives DESCRIPTIVE zero because a person
  /// marks it afterwards, but the teacher still has to be able to write the
  /// answer and it is still stored on the attempt for whoever marks it.
  group('the DESCRIPTIVE question in test4', () {
    final question = parse('OilcCZPh4gF9fJ5PCApl').questions[4];

    test('is written, not unanswerable', () {
      expect(question.isDescriptive, isTrue);
      expect(question.isWritten, isTrue, reason: 'the box must be rendered');
    });

    test('carries the author\'s own 2000 character limit', () {
      expect(question.maxCharLength, 2000);
      expect(question.characterLimit, 2000);
    });

    test('a real TEXT question uses its OWN stored limit', () {
      // MEOW's question carries 400 explicitly. An earlier version of this test
      // asserted the field was absent, which was simply wrong about the data.
      final text = parse('DHJ97HziClo5jeIVdPqI').questions.single;

      expect(text.maxCharLength, 400);
      expect(text.characterLimit, 400);
    });

    test('the fallback differs by TYPE where the author set no limit', () {
      // The distinction that matters: an unset limit must not give a
      // descriptive answer the same short box as a short-text one.
      const text = QuizQuestion(
        questionTitle: 'q',
        questionType: 'TEXT',
        marks: 1,
      );
      const descriptive = QuizQuestion(
        questionTitle: 'q',
        questionType: 'DESCRIPTIVE',
        marks: 1,
      );

      expect(text.characterLimit, 400);
      expect(descriptive.characterLimit, 2000);
    });

    test('the written answer reaches the stored attempt', () {
      // Scoring zero must not mean the answer is thrown away: whoever marks it
      // later reads it off the attempt.
      final stamped = stampAnswers(
        [question],
        [const QuizAnswer(text: 'A show about dragons.')],
      );

      expect(stamped.single['text'], 'A show about dragons.');
    });

    test('and it still scores zero out of its own marks', () {
      final marks = attemptMarks(
        [question],
        [const QuizAnswer(text: 'A show about dragons.')],
      );

      // Relative to the question rather than a literal, so editing the
      // assignment upstream does not break the test for the wrong reason.
      expect(marks.maxScore, question.marks);
      expect(marks.maxScore, greaterThan(0));
      expect(marks.studentScore, 0, reason: 'a person marks this, not the app');
    });
  });
}
