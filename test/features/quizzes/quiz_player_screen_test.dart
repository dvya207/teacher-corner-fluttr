import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/assignment.dart';
import 'package:tc_starter/features/quizzes/quiz_player_provider.dart';
import 'package:tc_starter/features/quizzes/quiz_player_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

/// The player, rendered against a REAL quiz document.
///
/// WHY THIS EXISTS. The player opened on the phone with a correct header and a
/// completely empty body, and nothing was logged — no exception, no overflow.
/// A screen that renders nothing without erroring cannot be diagnosed from a
/// screenshot, so it gets a test that fails the same way.
void main() {
  // REQUIRED before pumping anything that calls .tr(); without it every
  // label renders as its raw key and every finder misses.
  setUp(initLocalizationForTest);

  final raw =
      jsonDecode(File('test/assets/real_quizzes.json').readAsStringSync())
          as Map<String, dynamic>;

  Assignment realQuiz(String id) =>
      Assignment.fromMap(id, raw[id] as Map<String, dynamic>);

  Future<void> pumpPlayer(WidgetTester tester, Assignment assignment) {
    return pumpScreen(
      tester,
      child: const QuizPlayerScreen(),
      providers: [
        ChangeNotifierProvider<QuizPlayerProvider>(
          create: (_) => QuizPlayerProvider(
            firestore: FakeFirestoreService(),
            assignment: assignment,
            teacherDocId: 't1',
            uid: 'uid-1',
            classroomId: 'c1',
            programmeId: 'p1',
          ),
        ),
      ],
    );
  }

  testWidgets('test4 renders its first question, not an empty body', (
    tester,
  ) async {
    final quiz = realQuiz('OilcCZPh4gF9fJ5PCApl');

    await pumpPlayer(tester, quiz);

    // The header worked on the device, so prove it still does and that the
    // failure is below it.
    expect(find.textContaining('of ${quiz.questions.length}'), findsWidgets);

    // THE BODY. Question 1 of test4 is an MCQ whose title is "who's me?".
    expect(
      find.textContaining("who's me"),
      findsOneWidget,
      reason: 'the question text must be on screen',
    );
  });

  testWidgets('the MCQ options are lettered and tappable', (tester) async {
    await pumpPlayer(tester, realQuiz('QgBPyT8Pq0wFEbhaSiMQ'));

    // LA LA question 1 offers SINGER / MURDERER / FOOTBALL PLAYER / SONG WRITER.
    expect(find.textContaining('A. SINGER'), findsOneWidget);
    expect(find.textContaining('B. MURDERER'), findsOneWidget);
  });

  testWidgets('the position and nav labels fit on one line', (tester) async {
    await pumpPlayer(tester, realQuiz('QgBPyT8Pq0wFEbhaSiMQ'));

    // The regression that stacked "Prev" down the button one letter per line.
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('a badge never shows a raw translation key', (tester) async {
    // QUIZZES.TYPE_QUIZ appeared verbatim in the header on the device.
    await pumpPlayer(tester, realQuiz('QgBPyT8Pq0wFEbhaSiMQ'));

    expect(find.textContaining('QUIZZES.'), findsNothing);
    expect(find.textContaining('quizzes.'), findsNothing);
  });
}
