import 'package:flutter/widgets.dart';

/// The locales this app actually ships translations for.
///
/// One list, used by `main.dart` to configure EasyLocalization AND by the
/// profile screen to draw the language chips. Two lists would drift, and the
/// failure mode is a chip that switches to a language with no strings behind it.
///
/// Adding one here plus the matching `assets/l10n/<code>.json` is the whole
/// job: the picker grows on its own, and `test/core/l10n/locales_test.dart`
/// then fails until that file is complete, so a half-translated language cannot
/// reach a teacher.
///
/// ORDER IS THE PICKER'S ORDER, so it is not alphabetical by accident. English
/// first, because it is the fallback, then the Indian languages in the order the
/// programme uses them. Changing this order changes the chip row and the
/// dropdown together, which is the point of there being one list.
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('hi'),
  Locale('mr'),
  Locale('ta'),
  Locale('te'),
  Locale('kn'),
  Locale('bn'),
  Locale('gu'),
  Locale('or'),
  Locale('ur'),
  // The reference design shows an eleventh chip, `TR`. It is deliberately
  // NOT offered: `tr` is the ISO code for TURKISH, so declaring it would make
  // the platform format dates in Turkish and apply Turkish dotless-i casing
  // rules, and no translation exists for whatever language that chip was
  // meant to be. Ten languages, all of them complete.
];

/// Fallback when a locale has no translation for a key.
const Locale kFallbackLocale = Locale('en');

/// The locales written right to left.
///
/// Urdu is the only one today. A set rather than an inline comparison, so adding
/// Arabic or Farsi is one entry, and so the check reads as a property of the
/// language rather than a special case inside one screen.
const Set<String> kRtlLanguageCodes = {'ur'};

/// Whether [code] is written right to left.
///
/// Used where a language NAME must render in its own direction regardless of the
/// interface language — the picker has to show اردو correctly to someone reading
/// an English screen, which is the whole point of listing names natively.
bool isRtl(String code) => kRtlLanguageCodes.contains(code);
