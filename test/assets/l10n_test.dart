import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards ground rule 1 mechanically. Retrofitting i18n is miserable; noticing
/// a missing translation the moment it is added costs nothing.
///
/// Reads the JSON off disk rather than through easy_localization, so it needs no
/// widget tree and no bundle.
Map<String, String> _flatten(Map<String, dynamic> json, [String prefix = '']) {
  final out = <String, String>{};
  json.forEach((key, value) {
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      out.addAll(_flatten(value, path));
    } else {
      out[path] = value.toString();
    }
  });
  return out;
}

Map<String, String> _load(String locale) {
  final file = File('assets/l10n/$locale.json');
  expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
  return _flatten(
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
  );
}

void main() {
  late Map<String, String> en;
  late Map<String, String> hi;

  setUp(() {
    en = _load('en');
    hi = _load('hi');
  });

  test('en carries every string, and there are some', () {
    expect(en, isNotEmpty);
    expect(en.values.any((v) => v.trim().isEmpty), isFalse,
        reason: 'an empty string renders as a blank line on screen');
  });

  test('hi has no orphan keys that en does not define', () {
    // An orphan is always a bug: either a key was renamed in en and missed
    // here, or a string exists in hi that no code path can reach.
    expect(hi.keys.where((k) => !en.containsKey(k)), isEmpty);
  });

  test('hi covers the navigation at minimum', () {
    // The floor set by the definition of done.
    for (final key in en.keys.where((k) => k.startsWith('nav.'))) {
      expect(hi.containsKey(key), isTrue, reason: '$key is untranslated');
    }
  });

  test('hi is fully translated', () {
    // Currently true, and cheaper to keep true than to catch up on later. If
    // partial translation ever becomes the accepted contract, rewrite this test
    // to that contract rather than deleting it.
    expect(en.keys.where((k) => !hi.containsKey(k)), isEmpty);
  });

  test('placeholder counts match, so .tr(args:) cannot misalign', () {
    // "{} students" translated without its {} silently drops the number.
    for (final entry in en.entries) {
      final translated = hi[entry.key];
      if (translated == null) continue;
      final enSlots = '{}'.allMatches(entry.value).length;
      final hiSlots = '{}'.allMatches(translated).length;
      expect(hiSlots, enSlots,
          reason: '${entry.key}: en has $enSlots placeholders, hi has $hiSlots');
    }
  });

  test('no string looks like a leaked secret or a real phone number', () {
    // Ground rule 5, enforced rather than remembered.
    final suspicious = RegExp(
      r'(\+91\d{10})|(AIza[\w-]{10,})|(sk_[A-Za-z0-9]{10,})',
    );
    for (final entry in {...en, ...hi}.entries) {
      expect(suspicious.hasMatch(entry.value), isFalse,
          reason: '${entry.key} contains something that should not ship');
    }
  });
}
