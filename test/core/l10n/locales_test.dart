import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/l10n/locales.dart';

/// Guards the promise that every locale in the picker actually works.
///
/// The failure this prevents is specific and easy to ship: a chip appears,
/// a teacher taps it, and half the screens stay in English because the JSON is
/// missing keys. easy_localization falls back silently per key, so nothing
/// crashes and nobody notices until a teacher is mid-class.
void main() {
  Map<String, String> flatten(Map<String, dynamic> json, [String prefix = '']) {
    final out = <String, String>{};
    json.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        out.addAll(flatten(value, '$prefix$key.'));
      } else {
        out['$prefix$key'] = value.toString();
      }
    });
    return out;
  }

  // Plain throw, not `expect`: this is also called at the top level to load the
  // reference file, and `expect` outside a test body raises
  // OutsideTestException.
  Map<String, String> load(String code) {
    final file = File('assets/l10n/$code.json');
    if (!file.existsSync()) {
      throw StateError(
        'assets/l10n/$code.json is missing, but $code is in kSupportedLocales, '
        'so the picker offers a language that cannot load',
      );
    }
    return flatten(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  final english = load('en');

  test('en is the reference and is not empty', () {
    expect(english, isNotEmpty);
  });

  for (final locale in kSupportedLocales) {
    final code = locale.languageCode;

    group('$code.json', () {
      late Map<String, String> translations;

      setUp(() => translations = load(code));

      test('exists at all', () {
        expect(File('assets/l10n/$code.json').existsSync(), isTrue);
      });

      test('carries every key en does', () {
        final missing = english.keys
            .where((k) => !translations.containsKey(k))
            .toList()
          ..sort();
        expect(
          missing,
          isEmpty,
          reason: '$code is missing ${missing.length} key(s); those screens '
              'would silently fall back to English',
        );
      });

      test('carries no key en does not', () {
        // Usually a typo in a key path, which reads as a translation that never
        // appears anywhere.
        final unknown = translations.keys
            .where((k) => !english.containsKey(k))
            .toList()
          ..sort();
        expect(unknown, isEmpty);
      });

      test('keeps the same placeholder count on every key', () {
        // `{}` is POSITIONAL. A dropped one means `.tr(args: [...])` renders a
        // literal brace or loses a value; an extra one shifts every argument
        // after it.
        for (final key in english.keys) {
          if (!translations.containsKey(key)) continue;
          expect(
            translations[key]!.split('{}').length - 1,
            english[key]!.split('{}').length - 1,
            reason: '$code.$key has a different number of {} than en',
          );
        }
      });

      test('names itself in the language picker', () {
        // The profile screen renders `language.<current>`, so a locale that does
        // not name itself shows a raw key where the language name should be.
        expect(
          translations['language.$code'],
          isNotNull,
          reason: 'language.$code must exist in $code.json',
        );
        expect(translations['language.$code'], isNotEmpty);
      });

      test('translates something, rather than copying English wholesale', () {
        // A file created by copying en.json and forgetting to translate it would
        // pass every check above. Not applicable to en itself.
        if (code == 'en') return;
        final identical = english.keys
            .where((k) => translations[k] == english[k])
            .length;
        expect(
          identical / english.length,
          lessThan(0.5),
          reason: '$code matches en on $identical of ${english.length} keys, '
              'which suggests it was copied rather than translated',
        );
      });
    });
  }
}
