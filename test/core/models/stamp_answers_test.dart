import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/assignment.dart';
import 'package:tc_starter/core/models/quiz_scoring.dart';

/// What an ATTEMPT stores, as opposed to what was answered.
///
/// The stored attempt has to stand alone: the assignment can be edited after the
/// attempt was made, so a reader must be able to see the question, its options,
/// which were correct AND which were picked without joining back.
void main() {
  test('stamps attemptedOption onto every option, chosen or not', () {
    final stamped = stampAnswers(
      [
        const QuizQuestion(
          questionTitle: 'q',
          questionType: 'MCQ',
          marks: 1,
          options: [
            AssignmentOption(name: 'a', isCorrect: true),
            AssignmentOption(name: 'b', isCorrect: false),
          ],
        ),
      ],
      [
        const QuizAnswer(chosen: [1]),
      ],
    );

    final options = stamped.single['options'] as List;

    expect(options[0]['attemptedOption'], isFalse);
    expect(options[1]['attemptedOption'], isTrue);
    // The correctness flags survive, which is what makes the row reviewable.
    expect(options[0]['isCorrect'], isTrue);
  });

  test('writes timeTaken as null on every question', () {
    // Production has the field and this player does not time questions. A zero
    // would read as "answered instantly".
    final stamped = stampAnswers(
      [const QuizQuestion(questionTitle: 'q', questionType: 'TEXT', marks: 1)],
      [const QuizAnswer(text: 'hello')],
    );

    expect(stamped.single.containsKey('timeTaken'), isTrue);
    expect(stamped.single['timeTaken'], isNull);
  });

  test('a text answer is stored under production\'s own field name', () {
    final stamped = stampAnswers(
      [const QuizQuestion(questionTitle: 'q', questionType: 'TEXT', marks: 1)],
      [const QuizAnswer(text: 'hello')],
    );

    expect(stamped.single['text'], 'hello');
  });

  test('typed blanks go in blanksAnswered, NOT into selectedOption', () {
    // Production's blanks are dropdowns and it stores a selected option object.
    // This player types, so there is no option to store; naming the field
    // differently is honest, writing a string where an object is expected is not.
    final stamped = stampAnswers(
      [
        const QuizQuestion(
          questionTitle: 'q',
          questionType: 'FILL_IN_THE_BLANKS',
          marks: 1,
          blanks: {
            'optionsBlank1': [AssignmentOption(name: 'red', isCorrect: true)],
          },
        ),
      ],
      [
        const QuizAnswer(blanks: {'optionsBlank1': 'red'}),
      ],
    );

    expect(stamped.single['blanksAnswered'], {'optionsBlank1': 'red'});
    expect(stamped.single.containsKey('selectedOption'), isFalse);
  });

  test('an unanswered question carries no text or blanks key', () {
    final stamped = stampAnswers(
      [const QuizQuestion(questionTitle: 'q', questionType: 'TEXT', marks: 1)],
      [const QuizAnswer()],
    );

    expect(stamped.single.containsKey('text'), isFalse);
    expect(stamped.single.containsKey('blanksAnswered'), isFalse);
  });
}
