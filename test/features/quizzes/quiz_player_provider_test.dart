import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/assignment.dart';
import 'package:tc_starter/features/quizzes/quiz_player_provider.dart';

import '../../support/fakes.dart';

Assignment quiz({List<QuizQuestion> questions = const [], int allowed = 1}) =>
    Assignment(
      docId: 'a1',
      displayName: 'LA LA',
      type: 'QUIZ',
      allowedSubmissions: allowed,
      questions: questions,
    );

QuizQuestion mcq({bool single = false}) => QuizQuestion(
  questionTitle: '<p>Who is <strong>Justin</strong>?</p>',
  questionType: 'MCQ',
  marks: 1,
  oneCorrectOption: single,
  options: const [
    AssignmentOption(name: 'Singer', isCorrect: true),
    AssignmentOption(name: 'Murderer', isCorrect: false),
  ],
);

QuizPlayerProvider player(
  FakeFirestoreService firestore, {
  List<QuizQuestion> questions = const [],
  int allowed = 1,
}) => QuizPlayerProvider(
  firestore: firestore,
  assignment: quiz(questions: questions, allowed: allowed),
  teacherDocId: 't1',
  uid: 'uid-1',
  classroomId: 'c1',
  programmeId: 'p1',
);

void main() {
  group('choosing options', () {
    test('a SINGLE-choice question replaces rather than adds', () {
      // The scorer needs the chosen set to match the correct set EXACTLY, so a
      // stale selection left behind scores zero on a question answered right.
      final provider = player(
        FakeFirestoreService(),
        questions: [mcq(single: true)],
      );

      provider.toggleOption(0);
      provider.toggleOption(1);

      expect(provider.currentAnswer.chosen, [1]);
    });

    test('a MULTI-choice question toggles', () {
      final provider = player(FakeFirestoreService(), questions: [mcq()]);

      provider.toggleOption(0);
      provider.toggleOption(1);

      expect(provider.currentAnswer.chosen, [0, 1]);

      provider.toggleOption(0);

      expect(provider.currentAnswer.chosen, [1]);
    });
  });

  group('submitting', () {
    test('writes once and reports the score', () async {
      final firestore = FakeFirestoreService();
      final provider = player(firestore, questions: [mcq(single: true)]);

      provider.toggleOption(0);
      await provider.submit();

      expect(provider.status, QuizPlayerStatus.submitted);
      expect(firestore.savedAttempts, hasLength(1));
      expect(firestore.savedAttempts.single['studentScore'], 1.0);
      expect(firestore.savedAttempts.single['classroomId'], 'c1');
      expect(firestore.savedAttempts.single['programmeId'], 'p1');
    });

    test('a second submit is IGNORED, not queued', () async {
      // Guards the double-tap. A second write would burn another of a strictly
      // limited number of allowed attempts.
      final firestore = FakeFirestoreService();
      final provider = player(firestore, questions: [mcq()]);

      await provider.submit();
      await provider.submit();

      expect(firestore.savedAttempts, hasLength(1));
    });

    test('the cap is reported as final, not as something to retry', () async {
      final firestore = FakeFirestoreService(attemptsAlreadyUsed: 1);
      final provider = player(firestore, questions: [mcq()], allowed: 1);

      await provider.submit();

      expect(provider.status, QuizPlayerStatus.error);
      expect(provider.capReached, isTrue);
      expect(provider.errorKey, 'quizzes.cap_reached');
    });

    test('a transient failure is told apart from the cap', () async {
      // The remedy differs, so offering Retry on a cap would be a lie.
      final firestore = FakeFirestoreService(
        throwsOnSaveAttempt: Exception('network'),
      );
      final provider = player(firestore, questions: [mcq()]);

      await provider.submit();

      expect(provider.capReached, isFalse);
      expect(provider.errorKey, 'quizzes.submit_failed');
    });
  });

  test('navigation stays inside the question list', () {
    final provider = player(FakeFirestoreService(), questions: [mcq(), mcq()]);

    expect(provider.hasPrevious, isFalse);

    provider.next();
    expect(provider.index, 1);
    expect(provider.hasNext, isFalse);

    provider.next();
    expect(provider.index, 1, reason: 'cannot run off the end');

    provider.previous();
    provider.previous();
    expect(provider.index, 0, reason: 'cannot run off the start');
  });
}
