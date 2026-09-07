import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/assignment.dart';
import 'package:tc_starter/core/models/submission_report.dart';

/// Every stored value here is copied out of teacher-corner-dev, from
/// `users/7vbKdBSqG3YRI6X1GzFNeQD24Rm1/`. The four answer shapes in the first
/// group are the reason [SubmissionAnswer] holds a string rather than a
/// dynamic: all four are real, in one document.

/// The reflection form, as `formResponses/8Wr9b1vxdk5YAKrmuNHb-KhcHeF3Sir8TKH1x8NsI`
/// stores it.
Map<String, dynamic> reflectionResponse() => {
  'answers': {
    '1': ['very easy'],
    '2': ['mostly appropriate'],
    '3': ['moderately improved'],
    '4': ['mostly effective'],
    '5': 'nothing',
    '6': 3,
  },
  'teacherId': '7vbKdBSqG3YRI6X1GzFNeQD24Rm1',
  'assignmentId': 'KhcHeF3Sir8TKH1x8NsI',
  'classroomId': '8Wr9b1vxdk5YAKrmuNHb',
};

/// A form assignment whose questions those answers are keyed against.
///
/// `questions` WITH `questionNumber`, which is the field pair a FORM stores.
/// A quiz uses `questionsData` instead; see the note in [Assignment.fromMap].
Assignment reflectionAssignment() => Assignment.fromMap('KhcHeF3Sir8TKH1x8NsI', {
  'displayName': 'reflection form',
  'type': 'FORM',
  'questions': [
    {'questionNumber': 1, 'question': 'How easy or difficult was it?'},
    {'questionNumber': 2, 'question': 'Was it appropriate?'},
    {'questionNumber': 3, 'question': 'Did it improve interest?'},
    {'questionNumber': 4, 'question': 'How effective was it?'},
    {'questionNumber': 5, 'question': 'Anything to share?'},
    {'questionNumber': 6, 'question': 'How many groups finished?'},
  ],
});

/// The quiz attempt, as the submissions document's own top level stores it.
Map<String, dynamic> quizRecord() => {
  'teacherId': '7vbKdBSqG3YRI6X1GzFNeQD24Rm1',
  'assignmentId': 'QgBPyT8Pq0wFEbhaSiMQ',
  'displayName': 'LA LA',
  'totalQuestions': 5,
  'attemptsCount': 1,
  'maxScore': 5,
  'latestAttempt': {
    'attemptNumber': 1,
    'studentScore': 5,
    'maxScore': 5,
    'percentage': 100,
    'displayName': 'LA LA',
  },
};

void main() {
  group('a form block reads every shape an answer is stored in', () {
    test('all four shapes flatten to a line of text', () {
      final block = SubmissionParser.formBlock(
        assignment: reflectionAssignment(),
        response: reflectionResponse(),
      )!;

      expect(block.kind, SubmissionBlockKind.form);
      expect(block.title, 'reflection form');
      expect(block.answers, hasLength(6));

      // A single choice, stored in a list.
      expect(block.answers[0].answer, 'very easy');
      // Free text.
      expect(block.answers[4].answer, 'nothing');
      // A number.
      expect(block.answers[5].answer, '3');
    });

    test('several choices join on one line', () {
      // From the pre-test form: {"1": ["yes", "partially"]}.
      final block = SubmissionParser.formBlock(
        assignment: Assignment.fromMap('a', {
          'type': 'FORM',
          'questions': [
            {'questionNumber': 1, 'question': 'Was the pre-test conducted?'},
          ],
        }),
        response: {
          'answers': {
            '1': ['yes', 'partially'],
          },
        },
      )!;

      expect(block.answers.single.answer, 'yes, partially');
    });

    test('the QUESTION text is used, never the stored key', () {
      final block = SubmissionParser.formBlock(
        assignment: reflectionAssignment(),
        response: reflectionResponse(),
      )!;

      // "1" tells a teacher nothing about what they answered.
      expect(block.answers.first.question, 'How easy or difficult was it?');
      expect(block.answers.first.question, isNot('1'));
    });

    test('an unanswered question keeps its place in the list', () {
      // THE CASE THE SHEET SHOWS AS A DASH. The evidence form in live data has
      // both questions blank, and the block still has to render them.
      final block = SubmissionParser.formBlock(
        assignment: reflectionAssignment(),
        response: {
          'answers': {'1': ['very easy']},
        },
      )!;

      expect(block.answers, hasLength(6));
      expect(block.answers[0].isAnswered, isTrue);
      expect(block.answers[1].isAnswered, isFalse);
      expect(block.answers[1].answer, isEmpty);
      // Every question blank means the block has nothing in it.
      expect(block.isEmpty, isFalse);
    });

    test('answers survive an assignment that could not be read', () {
      // Labelled by number, which is all there is to go on, rather than
      // dropped. A teacher's answers are not lost because a document is.
      final block = SubmissionParser.formBlock(
        assignment: null,
        response: reflectionResponse(),
      )!;

      expect(block.answers, hasLength(6));
      expect(block.answers.first.question, 'Question 1');
      expect(block.answers.first.answer, 'very easy');
    });

    test('no questions and no answers is no block at all', () {
      expect(
        SubmissionParser.formBlock(assignment: null, response: null),
        isNull,
      );
    });
  });

  group('an upload block', () {
    test('takes its photos from storagePaths', () {
      final block = SubmissionParser.uploadBlock(
        assignment: null,
        entry: {
          'displayName': 'Observation evidence upload',
          'type': 'UPLOAD',
          'storagePaths': [
            'teacher_submissions/uid/a.jpg',
            'teacher_submissions/uid/b.jpg',
          ],
        },
      )!;

      expect(block.kind, SubmissionBlockKind.upload);
      expect(block.title, 'Observation evidence upload');
      expect(block.photoPaths, hasLength(2));
      expect(block.isEmpty, isFalse);
    });

    test('an upload with an empty storagePaths reads as nothing submitted', () {
      // EXACTLY WHAT IS IN LIVE DATA. The evidence entry for
      // DR1FNGAsj09unZYDKgLq has `storagePaths: []` and `photoUrls: []`: the
      // block was reached and nothing was handed in.
      final block = SubmissionParser.uploadBlock(
        assignment: null,
        entry: {
          'displayName': 'Observation evidence upload',
          'storagePaths': <dynamic>[],
          'photoUrls': <dynamic>[],
        },
      )!;

      expect(block.photoPaths, isEmpty);
      expect(block.isEmpty, isTrue);
    });

    test('no entry is no block', () {
      expect(
        SubmissionParser.uploadBlock(assignment: null, entry: null),
        isNull,
      );
    });
  });

  group('a quiz block', () {
    test('reads the score off latestAttempt', () {
      final block = SubmissionParser.quizBlock(
        assignment: null,
        record: quizRecord(),
      )!;

      expect(block.kind, SubmissionBlockKind.quiz);
      expect(block.title, 'LA LA');
      expect(block.quiz!.score, 5);
      expect(block.quiz!.maxScore, 5);
      expect(block.quiz!.attempts, 1);
      expect(block.quiz!.percentage, 100);
      expect(block.isEmpty, isFalse);
    });

    test('a record with no attempt yet is no block', () {
      // The document exists because something else was written to it.
      expect(
        SubmissionParser.quizBlock(
          assignment: null,
          record: {'teacherId': 'uid', 'classroomId': 'c1'},
        ),
        isNull,
      );
      expect(
        SubmissionParser.quizBlock(assignment: null, record: null),
        isNull,
      );
    });
  });

  group('an activity counts what was actually handed in', () {
    test('a submitted upload counts, an empty one does not', () {
      final activity = ActivitySubmissions(
        learningUnitId: '2awVLuyYaxFqMFuVp3Ny',
        blocks: [
          SubmissionParser.uploadBlock(
            assignment: null,
            entry: {'storagePaths': ['a/b.jpg']},
          )!,
          SubmissionParser.uploadBlock(
            assignment: null,
            entry: {'storagePaths': <dynamic>[]},
          )!,
        ],
      );

      expect(activity.totalCount, 2);
      expect(activity.submittedCount, 1);
      // WHICH IS WHAT THE PERSON ROW READS. "Not submitted" has to mean
      // nothing was handed in, not that the workflow declared no blocks.
      expect(activity.hasAnySubmission, isTrue);
    });

    test('an activity with only empty blocks reads as not submitted', () {
      final activity = ActivitySubmissions(
        learningUnitId: 'lu1',
        blocks: [
          SubmissionParser.uploadBlock(
            assignment: null,
            entry: {'storagePaths': <dynamic>[]},
          )!,
        ],
      );

      expect(activity.hasAnySubmission, isFalse);
      expect(activity.submittedCount, 0);
    });

    test('a deleted unit still names the row by its id', () {
      const activity = ActivitySubmissions(learningUnitId: 'gone', unit: null);
      expect(activity.label, 'gone');
    });
  });
}
