import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/l10n/locales.dart';
import 'package:tc_starter/core/models/teacher_account.dart';
import 'package:tc_starter/features/auth/auth_provider.dart';
import 'package:tc_starter/features/profile/profile_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

/// The language picker: a chip row and a dropdown of native names.
///
/// Both read [kSupportedLocales], so the test that matters most is that they
/// agree with each other and with the files on disk. A chip for a language whose
/// JSON is missing keys is the failure this whole area exists to prevent.

Map<String, dynamic> languageSection() {
  final json =
      jsonDecode(File('assets/l10n/en.json').readAsStringSync()) as Map<String, dynamic>;
  return json['language'] as Map<String, dynamic>;
}

Future<void> pumpProfile(WidgetTester tester) => pumpScreen(
      tester,
      child: const ProfileScreen(),
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => StubAuthProvider(
            stubAccount: const TeacherAccount(uid: 'uid_any_000000000000001'),
          ),
        ),
      ],
    );

void main() {
  setUp(initLocalizationForTest);

  group('the offered set', () {
    test('ten languages are offered', () {
      expect(kSupportedLocales.length, 10);
    });

    test('English is first, because it is the fallback', () {
      expect(kSupportedLocales.first.languageCode, 'en');
      expect(kFallbackLocale.languageCode, 'en');
    });

    test('Turkish is NOT offered', () {
      // `tr` is the ISO code for Turkish. Declaring it would make the platform
      // format dates in Turkish and apply Turkish dotless-i casing, and no
      // translation exists for the language that chip was meant to be.
      expect(
        kSupportedLocales.map((l) => l.languageCode),
        isNot(contains('tr')),
      );
      expect(languageSection().containsKey('tr'), isFalse);
    });

    test('every offered locale has a native name, and vice versa', () {
      final offered = kSupportedLocales.map((l) => l.languageCode).toSet();
      final named = languageSection().keys.toSet();

      // Equality both ways: a name with no locale is a chip that never appears,
      // and a locale with no name renders the raw key in the dropdown.
      expect(named, equals(offered));
    });

    test('no locale is listed twice', () {
      final codes = kSupportedLocales.map((l) => l.languageCode).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('only Urdu is marked right-to-left', () {
      expect(kRtlLanguageCodes, {'ur'});
      expect(isRtl('ur'), isTrue);
      expect(isRtl('en'), isFalse);
      expect(isRtl('ta'), isFalse);
    });
  });

  group('the chip row', () {
    testWidgets('renders one chip per offered language', (tester) async {
      await pumpProfile(tester);

      for (final locale in kSupportedLocales) {
        expect(
          find.text(locale.languageCode.toUpperCase()),
          findsOneWidget,
          reason: 'no chip for ${locale.languageCode}',
        );
      }
    });

    testWidgets('does not render a chip for an unoffered language',
        (tester) async {
      await pumpProfile(tester);
      expect(find.text('TR'), findsNothing);
    });
  });

  group('the dropdown', () {
    testWidgets('shows the current language by its own name', (tester) async {
      await pumpProfile(tester);

      // The harness loads English, so the collapsed control reads "English"
      // rather than "EN" — the point of the dropdown is names, not codes.
      expect(find.text('English'), findsWidgets);
    });

    testWidgets('opens to every language in its own script', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
      await tester.pumpAndSettle();

      final names = languageSection();
      for (final locale in kSupportedLocales) {
        final native = names[locale.languageCode] as String;
        expect(
          find.text(native),
          findsWidgets,
          reason: 'the menu is missing "$native" for ${locale.languageCode}',
        );
      }
    });

    testWidgets('names are native, not English', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
      await tester.pumpAndSettle();

      // A teacher who cannot read the current interface language has to find
      // their own language by its own name. These would all read as English
      // words if the menu were built from a translated label instead.
      expect(find.text('ಕನ್ನಡ'), findsWidgets);
      expect(find.text('தமிழ்'), findsWidgets);
      expect(find.text('اردو'), findsWidgets);
      expect(find.text('ଓଡ଼ିଆ'), findsWidgets);
    });

    testWidgets('the current language is ticked', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
      await tester.pumpAndSettle();

      // Exactly one, so the menu cannot claim two languages are current.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}
