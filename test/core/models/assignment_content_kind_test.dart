import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/form_question.dart';
import 'package:tc_starter/core/models/assignment.dart';
import 'package:tc_starter/core/models/workflow.dart';

/// The three assignment contents of the Swimming workflow, verbatim.
WorkflowContent content(String type) => WorkflowContent.fromMap({
  'contentName': 'x',
  'contentCategory': 'assignment',
  'contentSubCategory': '',
  'contentType': '',
  'resourcePath': '',
  'assignmentType': type,
  'assignmentId': 'a1',
});

void main() {
  group('telling the three assignment kinds apart', () {
    // THE BUG THIS GUARDS. The old rule was "type is UPLOAD or category is
    // assignment", so a QUIZ and a FORM both matched the second half and every
    // one of the three steps rendered the photo-evidence pane. A teacher
    // opening "Quizzzz" got a camera.
    test('a QUIZ is a quiz and nothing else', () {
      final c = content('QUIZ');
      expect(c.isQuizAssignment, isTrue);
      expect(c.isUploadAssignment, isFalse);
      expect(c.isFormAssignment, isFalse);
    });

    test('a FORM is a form and nothing else', () {
      final c = content('FORM');
      expect(c.isFormAssignment, isTrue);
      expect(c.isUploadAssignment, isFalse);
      expect(c.isQuizAssignment, isFalse);
    });

    test('an UPLOAD is still an upload', () {
      final c = content('UPLOAD');
      expect(c.isUploadAssignment, isTrue);
      expect(c.isQuizAssignment, isFalse);
      expect(c.isFormAssignment, isFalse);
    });

    test('an assignment with no type falls back to upload', () {
      // What the category alone used to mean. An upload pane at least degrades
      // to something a teacher can close.
      final c = content('');
      expect(c.isAssignment, isTrue);
      expect(c.isUploadAssignment, isTrue);
    });

    test('a plain content is no assignment at all', () {
      const c = WorkflowContent(
        contentName: 'Guide',
        contentCategory: 'tacDev',
        contentSubCategory: 'devGuidePdf',
      );
      expect(c.isAssignment, isFalse);
      expect(c.isUploadAssignment, isFalse);
      expect(c.isQuizAssignment, isFalse);
      expect(c.isFormAssignment, isFalse);
    });
  });

  group('a FORM assignment reads its own questions', () {
    // A QUIZ keeps its questions on `questionsData`; a FORM uses `questions`
    // and has no questionsData at all.
    Assignment peru() => Assignment.fromMap('e56a09', {
      'type': 'FORM',
      'displayName': 'Peru',
      'instructions': 'Please answer all the questions in the fields provided below',
      'questions': [
        {
          'questionType': 'text',
          'questionNumber': 1,
          'question': 'Did you like this song?',
          'prompt': '',
          'dropDownOptions': '',
        },
        {
          'questionType': 'starRating',
          'questionNumber': 3,
          'question': 'Rate your experience',
        },
        {
          'questionType': 'text',
          'questionNumber': 2,
          'question': 'Share your experience.',
        },
      ],
    });

    test('parses each question and sorts by its stated number', () {
      final form = peru();
      expect(form.formQuestions.map((q) => q.number), [1, 2, 3]);
      expect(form.formQuestions.first.question, 'Did you like this song?');
      expect(form.instructions, contains('answer all the questions'));
    });

    test('recognises a star rating from its type', () {
      final rating = peru().formQuestions.last;
      expect(rating.kind, FormAnswerKind.starRating);
      expect(rating.question, 'Rate your experience');
    });

    test('a quiz has no form questions, and a form no quiz questions', () {
      expect(peru().questions, isEmpty);
      final quiz = Assignment.fromMap('q1', {
        'type': 'QUIZ',
        'displayName': 'LA LA',
        'questionsData': [
          {'question': 'One?', 'questionNumber': 1},
        ],
      });
      expect(quiz.formQuestions, isEmpty);
      expect(quiz.questions, hasLength(1));
    });

    test('a question with no text is dropped, not numbered and blank', () {
      final form = Assignment.fromMap('f1', {
        'type': 'FORM',
        'questions': [
          {'questionNumber': 1, 'question': ''},
          {'questionNumber': 2, 'question': 'Real one'},
        ],
      });
      expect(form.formQuestions.map((q) => q.question), ['Real one']);
    });
  });

  group('when an answer counts as given', () {
    test('a blank or whitespace text answer does not', () {
      const q = FormQuestion(number: 1, question: 'x');
      expect(q.isAnswered(null), isFalse);
      expect(q.isAnswered(''), isFalse);
      expect(q.isAnswered('   '), isFalse);
      expect(q.isAnswered('yes'), isTrue);
    });

    test('a rating of zero does not, because zero means untouched', () {
      const q = FormQuestion(
        number: 1,
        question: 'x',
        kind: FormAnswerKind.starRating,
      );
      expect(q.isAnswered(0), isFalse);
      expect(q.isAnswered(null), isFalse);
      expect(q.isAnswered(1), isTrue);
      expect(q.isAnswered(5), isTrue);
    });
  });
}
