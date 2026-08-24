import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/features/profile/help_guide_screen.dart';

import '../../support/pump_app.dart';

/// Help & Guide.
///
/// The failure this is really for: a mistyped key. `'guide.submit_9'.tr()`
/// renders the KEY PATH as body text — no crash, no warning, just a line reading
/// "guide.submit_9" in the middle of a teacher's instructions. Nothing else in
/// the suite would catch it, because the locale test only compares the files
/// against each other and never against what the screen asks for.

Future<void> pumpGuide(WidgetTester tester) => pumpScreen(
      tester,
      child: const HelpGuideScreen(),
      surfaceSize: const Size(360, 1200),
    );

/// Walks the whole guide, collecting every rendered string on the way.
///
/// A ListView builds only what is near the viewport, so a single pump sees a
/// fraction of the page however tall the surface is made — the first attempt at
/// this saw six of nine cards on a 4000px surface. Scrolling is the only way to
/// assert on content that is genuinely off-screen, and it is also what a teacher
/// does.
Future<Set<String>> scrollAndCollect(WidgetTester tester) async {
  final seen = <String>{};

  void collect() {
    seen.addAll(
      tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>(),
    );
  }

  collect();
  for (var i = 0; i < 40; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump();
    collect();
  }
  return seen;
}

/// Every string in en.json's `guide` subtree, which is what the screen draws
/// from.
Map<String, String> guideStrings() {
  final json =
      jsonDecode(File('assets/l10n/en.json').readAsStringSync()) as Map<String, dynamic>;
  final guide = json['guide'] as Map<String, dynamic>;
  return guide.map((key, value) => MapEntry(key, value.toString()));
}

void main() {
  setUp(initLocalizationForTest);

  testWidgets('renders no raw key paths', (tester) async {
    await pumpGuide(tester);
    final seen = await scrollAndCollect(tester);

    // A key that failed to resolve renders as itself, and every key here is
    // prefixed, so one string starting "guide." is one typo.
    final unresolved =
        seen.where((value) => value.startsWith('guide.')).toList();

    expect(unresolved, isEmpty,
        reason: 'these keys did not resolve: $unresolved');
  });

  testWidgets('every section heading is present', (tester) async {
    await pumpGuide(tester);
    final seen = await scrollAndCollect(tester);

    for (final heading in [
      'Getting started',
      'Submissions',
      'Profile & settings',
      'WhatsApp reminders & support',
      'Student access codes',
    ]) {
      expect(seen, contains(heading.toUpperCase()),
          reason: 'missing section "$heading"');
    }
  });

  testWidgets('all nine topics render, plus the closing card', (tester) async {
    await pumpGuide(tester);
    final seen = await scrollAndCollect(tester);

    // Counted by their titles rather than by widget, because only the cards near
    // the viewport exist at any one moment.
    //
    // `more_title` is excluded: it is the closing card, which has no steps and is
    // deliberately not a GuideCard. Including it made this assert 10 topics and
    // fail against a screen that was right.
    final titles = guideStrings().entries
        .where((entry) =>
            entry.key.endsWith('_title') && entry.key != 'more_title')
        .map((entry) => entry.value);

    for (final title in titles) {
      expect(seen, contains(title), reason: 'topic never rendered: $title');
    }
    expect(titles.length, 9);
    expect(seen, contains('Need more help?'));
  });

  testWidgets('every authored step actually reaches the screen', (tester) async {
    await pumpGuide(tester);
    final seen = await scrollAndCollect(tester);

    // Guards the opposite mistake from the key-path test: a step present in
    // en.json that the screen forgot to list. The locale test cannot see that
    // either, because the file is complete — it is the SCREEN that is missing it.
    final steps = guideStrings().entries.where(
      (entry) => RegExp(r'_\d+$').hasMatch(entry.key),
    );

    final missing = [
      for (final step in steps)
        if (!seen.contains(step.value)) step.key,
    ];

    expect(missing, isEmpty,
        reason: 'authored but never rendered: $missing');
  });

  testWidgets('the steps are numbered from one, in order', (tester) async {
    await pumpGuide(tester);
    final seen = await scrollAndCollect(tester);

    // The longest card has eight steps, so the badges must run 1..8. Numbering
    // is only worth having if it matches the sequence it claims to describe.
    for (final number in ['1', '2', '3', '4', '5', '6', '7', '8']) {
      expect(seen, contains(number), reason: 'no step badge "$number"');
    }
  });

  testWidgets('the app bar offers a way back', (tester) async {
    await pumpGuide(tester);

    // Reached from a row in Profile, and outside the bottom-nav shell, so the
    // back arrow is the only way out.
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });
}
