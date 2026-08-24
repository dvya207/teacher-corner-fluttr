import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/core/models/teacher_account.dart';
import 'package:tc_starter/core/models/teacher_profile.dart';
import 'package:tc_starter/core/widgets/tc_avatar_chip.dart';
import 'package:tc_starter/features/dashboard/greeting.dart';

import '../../support/pump_app.dart';

/// The dashboard header: greeting, first name, avatar, institution.

TeacherAccount account({
  String? first,
  String? last,
  String? institution,
  String? teachingFirst,
}) =>
    TeacherAccount(
      uid: 'uid_header_000000000001',
      profile: (first == null && last == null && institution == null)
          ? null
          : TeacherProfile.fromMap('uid_header_000000000001', {
              'firstName': ?first,
              'lastName': ?last,
              'institutionName': ?institution,
            }),
      teaching: teachingFirst == null
          ? null
          : Teacher.fromMap('tch_header', {
              'teacherMeta': {'firstName': teachingFirst, 'lastName': 'Surname'},
            }),
    );

void main() {
  group('greetingKeyFor', () {
    test('morning up to noon', () {
      for (final hour in [0, 5, 9, 11]) {
        expect(
          greetingKeyFor(DateTime(2026, 8, 24, hour)),
          'dashboard.greeting_morning',
          reason: 'hour $hour should be morning',
        );
      }
    });

    test('afternoon from noon to five', () {
      for (final hour in [12, 14, 16]) {
        expect(
          greetingKeyFor(DateTime(2026, 8, 24, hour)),
          'dashboard.greeting_afternoon',
          reason: 'hour $hour should be afternoon',
        );
      }
    });

    test('evening from five', () {
      for (final hour in [17, 20, 23]) {
        expect(
          greetingKeyFor(DateTime(2026, 8, 24, hour)),
          'dashboard.greeting_evening',
          reason: 'hour $hour should be evening',
        );
      }
    });

    test('the boundaries land on the later band', () {
      // The only hours this can be wrong at, which is why the function takes a
      // time instead of reading the clock.
      expect(greetingKeyFor(DateTime(2026, 8, 24, 11, 59)),
          'dashboard.greeting_morning');
      expect(greetingKeyFor(DateTime(2026, 8, 24, 12, 0)),
          'dashboard.greeting_afternoon');
      expect(greetingKeyFor(DateTime(2026, 8, 24, 16, 59)),
          'dashboard.greeting_afternoon');
      expect(greetingKeyFor(DateTime(2026, 8, 24, 17, 0)),
          'dashboard.greeting_evening');
    });
  });

  group('firstName', () {
    test('is the profile first name, not the whole name', () {
      // "Good afternoon, Divya Jain" reads like a letter from an institution.
      expect(account(first: 'Divya', last: 'Jain').firstName, 'Divya');
    });

    test('falls back to the teaching record', () {
      expect(account(teachingFirst: 'Rohith').firstName, 'Rohith');
    });

    test('falls back to the first word of a single-field name', () {
      // A record carrying only a top-level `name` still has a first name in it.
      final teacher = Teacher.fromMap('tch_x', {'name': 'Anita Rao'});
      final acct = TeacherAccount(uid: 'u', teaching: teacher);

      expect(acct.firstName, 'Anita');
    });

    test('is empty when nothing is known', () {
      expect(const TeacherAccount(uid: 'u').firstName, '');
    });
  });

  group('initials', () {
    test('takes the first letter of the first two words', () {
      expect(account(first: 'Divya', last: 'Jain').initials, 'DJ');
    });

    test('takes one letter from a single-word name', () {
      expect(account(first: 'Divya').initials, 'D');
    });

    test('is empty when nothing is known, so the chip can say so', () {
      expect(const TeacherAccount(uid: 'u').initials, '');
    });

    test('uppercases a lowercase name', () {
      expect(account(first: 'divya', last: 'jain').initials, 'DJ');
    });
  });

  group('TcAvatarChip', () {
    setUp(initLocalizationForTest);

    testWidgets('renders the initials and calls back on tap', (tester) async {
      var taps = 0;
      await pumpScreen(
        tester,
        child: Scaffold(
          body: TcAvatarChip(initials: 'DJ', onTap: () => taps++),
        ),
      );

      expect(find.text('DJ'), findsOneWidget);

      await tester.tap(find.text('DJ'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('shows a single glyph rather than an empty circle',
        (tester) async {
      // A blank circle reads as a loading state rather than as an account.
      await pumpScreen(
        tester,
        child: const Scaffold(body: TcAvatarChip(initials: '')),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('is not a button when it has no destination', (tester) async {
      await pumpScreen(
        tester,
        child: const Scaffold(body: TcAvatarChip(initials: 'DJ')),
      );

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('keeps a 48px touch target around a smaller circle',
        (tester) async {
      // The drawn diameter and the comfortable touch area are not the same
      // question, and a 40px target on a phone held one-handed is not one.
      await pumpScreen(
        tester,
        child: Scaffold(
          body: TcAvatarChip(initials: 'DJ', diameter: 32, onTap: () {}),
        ),
      );

      final target = tester.getSize(
        find.ancestor(of: find.text('DJ'), matching: find.byType(SizedBox)).last,
      );
      expect(target.width, greaterThanOrEqualTo(TcAvatarChip.minTarget));
      expect(target.height, greaterThanOrEqualTo(TcAvatarChip.minTarget));
    });
  });
}
