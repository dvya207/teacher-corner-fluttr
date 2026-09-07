import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/assignment.dart';
import 'package:tc_starter/features/learning_unit/widgets/form_panel.dart';

import '../../support/pump_app.dart';

Assignment peru() => Assignment.fromMap('e56a09', {
  'type': 'FORM',
  'displayName': 'Peru',
  'instructions': 'Please answer all the questions in the fields provided below',
  'questions': [
    {'questionType': 'text', 'questionNumber': 1, 'question': 'Did you like it?'},
    {'questionType': 'starRating', 'questionNumber': 2, 'question': 'Rate it'},
  ],
});

Future<void> pumpForm(
  WidgetTester tester, {
  required FormSubmitter onSubmit,
  Map<String, Object?>? existing,
  bool canSubmit = true,
  Assignment? assignment,
}) => pumpScreen(
  tester,
  child: Scaffold(
    body: FormPanel(
      assignment: assignment ?? peru(),
      onSubmit: onSubmit,
      existingAnswers: existing,
      canSubmit: canSubmit,
    ),
  ),
);

void main() {
  setUp(initLocalizationForTest);

  testWidgets('shows the instructions and every question', (tester) async {
    await pumpForm(tester, onSubmit: (_) async => true);

    expect(find.textContaining('answer all the questions'), findsOneWidget);
    expect(find.text('Did you like it?'), findsOneWidget);
    expect(find.text('Rate it'), findsOneWidget);
    expect(find.text('Submit Form'), findsOneWidget);
  });

  testWidgets('refuses to send a half-filled form, and saves nothing', (
    tester,
  ) async {
    // Checked BEFORE the write. A half-filled form saved and then complained
    // about is a teacher's work lost.
    var calls = 0;
    await pumpForm(tester, onSubmit: (_) async {
      calls++;
      return true;
    });

    await tester.tap(find.text('Submit Form'));
    await tester.pump();

    expect(calls, 0);
    expect(find.textContaining('answer every question'), findsOneWidget);
  });

  testWidgets('a rating of zero is not an answer', (tester) async {
    var calls = 0;
    await pumpForm(tester, onSubmit: (_) async {
      calls++;
      return true;
    });

    // Only the text question is answered; the rating is untouched.
    await tester.enterText(find.byType(TextField), 'yes');
    await tester.tap(find.text('Submit Form'));
    await tester.pump();

    expect(calls, 0);
  });

  testWidgets('a complete form is sent, keyed by question number', (
    tester,
  ) async {
    Map<String, Object?>? sent;
    await pumpForm(tester, onSubmit: (a) async {
      sent = a;
      return true;
    });

    await tester.enterText(find.byType(TextField), 'yes I did');
    // The fourth star.
    await tester.tap(find.byIcon(Icons.star_border_rounded).at(3));
    await tester.pump();
    await tester.tap(find.text('Submit Form'));
    await tester.pumpAndSettle();

    // Keyed by questionNumber, not array index: adding a question must not
    // renumber every answer already stored.
    expect(sent, {'1': 'yes I did', '2': 4});
    expect(find.text('Submitted'), findsOneWidget);
  });

  testWidgets('a failed save says so and does not claim success', (
    tester,
  ) async {
    await pumpForm(tester, onSubmit: (_) async => false);

    await tester.enterText(find.byType(TextField), 'yes');
    await tester.tap(find.byIcon(Icons.star_border_rounded).first);
    await tester.pump();
    await tester.tap(find.text('Submit Form'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not save your answers'), findsOneWidget);
    expect(find.text('Submitted'), findsNothing);
  });

  testWidgets('a previous submission reopens filled in', (tester) async {
    await pumpForm(
      tester,
      onSubmit: (_) async => true,
      existing: {'1': 'from last time', '2': 5},
    );

    expect(find.text('from last time'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Submit Again'), findsOneWidget);
    // Five filled stars.
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
  });

  testWidgets('with nowhere to write, it still shows but cannot send', (
    tester,
  ) async {
    // A teacher outside a classroom can read what is being asked; they just
    // cannot send it.
    await pumpForm(tester, onSubmit: (_) async => true, canSubmit: false);

    expect(find.text('Did you like it?'), findsOneWidget);
    expect(find.text('Submit Form'), findsNothing);
    expect(find.textContaining('from a classroom'), findsOneWidget);
  });

  testWidgets('a form with no questions says so', (tester) async {
    await pumpForm(
      tester,
      onSubmit: (_) async => true,
      assignment: Assignment.fromMap('f0', {'type': 'FORM', 'questions': []}),
    );

    expect(find.text('No questions yet'), findsOneWidget);
  });

  // -- checkBoxGroup, the multi-select type ---------------------------------
  //
  // THIS APP'S OWN TYPE, not one of production's seven, and the only form
  // question whose stored answer is a LIST rather than a string or a number.
  // Every test below is about that difference.

  Assignment multiSelectForm() => Assignment.fromMap('multi01', {
    'type': 'FORM',
    'displayName': 'After the activity',
    'instructions': 'Tell us how it went',
    'questions': [
      {
        'questionType': 'checkBoxGroup',
        'questionNumber': 1,
        'question': 'What got in the way?',
        // ONE STRING, COMMA SEPARATED, which is how this collection stores the
        // options for `dropDown` too. The web wizard writes the same field for
        // both types.
        'dropDownOptions': 'Time, Materials , Noise',
      },
    ],
  });

  // -- radioGroup, the single-select row type -------------------------------
  //
  // THE WEB APP'S OTHER ROW-AUTHORED TYPE. It needed no production change on this
  // side: 'radioGroup' already matched the existing 'radio' test and so renders
  // the radio group a `dropDown` does. These tests pin that, and pin that its
  // options come through from an ARRAY, which is the shape the wizard writes.

  Assignment radioForm() => Assignment.fromMap('radio01', {
    'type': 'FORM',
    'displayName': 'After the activity',
    'instructions': 'Tell us how it went',
    'questions': [
      {
        'questionType': 'radioGroup',
        'questionNumber': 1,
        'question': 'Did it run to time?',
        // AN ARRAY, and one option carries a comma. A joined string could not
        // express it, which is why these types store an array.
        'dropDownOptions': ['Yes', 'No', 'Only partly, we ran out of time'],
      },
    ],
  });

  testWidgets('renders a radioGroup as radios, one per option', (tester) async {
    await pumpForm(
      tester,
      onSubmit: (_) async => true,
      assignment: radioForm(),
    );

    expect(find.byType(RadioListTile<String>), findsNWidgets(3));
    expect(find.text('Only partly, we ran out of time'), findsOneWidget);
  });

  testWidgets('a radioGroup submits one string, not a list', (tester) async {
    Map<String, Object?>? sent;
    await pumpForm(
      tester,
      onSubmit: (answers) async {
        sent = answers;
        return true;
      },
      assignment: radioForm(),
    );

    await tester.tap(find.text('Only partly, we ran out of time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Form'));
    await tester.pumpAndSettle();

    expect(sent, {'1': 'Only partly, we ran out of time'});
  });

  /// PICKING AGAIN REPLACES, which is the whole difference from the checkbox
  /// group. Two picks there would both be kept.
  testWidgets('a second pick replaces the first', (tester) async {
    Map<String, Object?>? sent;
    await pumpForm(
      tester,
      onSubmit: (answers) async {
        sent = answers;
        return true;
      },
      assignment: radioForm(),
    );

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Form'));
    await tester.pumpAndSettle();

    expect(sent, {'1': 'No'});
  });

  testWidgets('renders every option as its own checkbox', (tester) async {
    await pumpForm(
      tester,
      onSubmit: (_) async => true,
      assignment: multiSelectForm(),
    );

    expect(find.text('What got in the way?'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    for (final option in ['Time', 'Materials', 'Noise']) {
      expect(find.text(option), findsOneWidget);
    }
  });

  testWidgets('will not submit until a box is ticked', (tester) async {
    var submitted = false;
    await pumpForm(
      tester,
      onSubmit: (_) async {
        submitted = true;
        return true;
      },
      assignment: multiSelectForm(),
    );

    await tester.tap(find.text('Submit Form'));
    await tester.pumpAndSettle();

    // NOTHING TICKED IS NOT AN ANSWER, the same rule a zero rating follows.
    expect(submitted, isFalse);
    expect(find.textContaining('answer every question'), findsOneWidget);
  });

  testWidgets('submits the ticked options as a list', (tester) async {
    Map<String, Object?>? sent;
    await pumpForm(
      tester,
      onSubmit: (answers) async {
        sent = answers;
        return true;
      },
      assignment: multiSelectForm(),
    );

    await tester.tap(find.text('Noise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Form'));
    await tester.pumpAndSettle();

    // IN THE QUESTION'S OWN ORDER, not the order they were tapped, so the same
    // set of boxes always stores the same list.
    expect(sent, {'1': ['Time', 'Noise']});
  });

  testWidgets('unticking the last box makes it unanswered again', (
    tester,
  ) async {
    var submitted = false;
    await pumpForm(
      tester,
      onSubmit: (_) async {
        submitted = true;
        return true;
      },
      assignment: multiSelectForm(),
    );

    await tester.tap(find.text('Noise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Noise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Form'));
    await tester.pumpAndSettle();

    expect(submitted, isFalse);
  });

  testWidgets('reopens with the saved options already ticked', (tester) async {
    await pumpForm(
      tester,
      onSubmit: (_) async => true,
      assignment: multiSelectForm(),
      existing: const {'1': ['Materials']},
    );

    final ticked = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .map((t) => t.value)
        .toList();

    expect(ticked, [false, true, false]);
  });

  testWidgets('drops a saved option the question no longer offers', (
    tester,
  ) async {
    await pumpForm(
      tester,
      onSubmit: (_) async => true,
      assignment: multiSelectForm(),
      // 'Weather' was ticked before someone edited the form and removed it.
      existing: const {'1': ['Weather', 'Time']},
    );

    final ticked = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .map((t) => t.value)
        .toList();

    // SHOWN AS ONE FEWER rather than as a choice the question does not offer.
    expect(ticked, [true, false, false]);
    expect(find.text('Weather'), findsNothing);
  });
}
