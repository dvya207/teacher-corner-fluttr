import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/learning_unit.dart';

/// A learning unit carries FIVE description fields and this is about which one
/// a teacher reads.
///
/// The text below is shortened from `learningUnits/W2IYxhjqMP6bqENWJUQC`
/// (House of Dragons) in teacher-corner-dev, which has all five filled with
/// different wording. Four of the six units there have none of them, which is
/// why the absent case matters as much as the present one.
LearningUnit unitWith(Map<String, dynamic> fields) =>
    LearningUnit.fromMap('W2IYxhjqMP6bqENWJUQC', {
      'learningUnitDisplayName': 'House of Dragons',
      ...fields,
    });

const _long = 'Dragons are legendary creatures often described as powerful, '
    'intelligent beings with enormous wings.';
const _short = 'Dragons are mythical creatures known for their powerful '
    'bodies, wings, sharp claws.';
const _altLong = 'Dragons are mythical creatures known for their powerful '
    'bodies and magical abilities.';
const _altShort = 'Dragons are powerful mythical creatures with wings, '
    'scales, sharp claws.';
const _tiny = 'Dragons are magical creatures known for their wings.';

void main() {
  group('the longest description wins', () {
    test('all five present yields the long one', () {
      // THE SCREEN THIS IS FOR is opened before running the activity, where a
      // teacher is deciding whether they understand it well enough to teach
      // it. More detail is better, so the order is longest first.
      final unit = unitWith({
        'longDescription': _long,
        'shortDescription': _short,
        'alternateLongDescription': _altLong,
        'alternateShortDescription': _altShort,
        'tinyDescription': _tiny,
      });

      expect(unit.description, _long);
    });

    test('it falls through the chain in order as each one empties', () {
      // Each step down is a real state: an author who filled only some of the
      // five, which the model used to read as no description at all for three
      // of them.
      expect(
        unitWith({
          'shortDescription': _short,
          'alternateLongDescription': _altLong,
          'tinyDescription': _tiny,
        }).description,
        _short,
      );
      expect(
        unitWith({
          'alternateLongDescription': _altLong,
          'alternateShortDescription': _altShort,
          'tinyDescription': _tiny,
        }).description,
        _altLong,
      );
      expect(
        unitWith({
          'alternateShortDescription': _altShort,
          'tinyDescription': _tiny,
        }).description,
        _altShort,
      );
      // THE LAST RESORT, not a preference.
      expect(unitWith({'tinyDescription': _tiny}).description, _tiny);
    });

    test('the three fields that used to be dropped are read at all', () {
      // A unit whose author filled ONLY an alternate showed nothing before,
      // because the model parsed shortDescription and longDescription and
      // ignored the other three.
      for (final field in [
        'alternateLongDescription',
        'alternateShortDescription',
        'tinyDescription',
      ]) {
        expect(
          unitWith({field: 'the only one filled'}).description,
          'the only one filled',
          reason: field,
        );
      }
    });
  });

  group('when there is nothing to show', () {
    test('a unit with no description at all is null, not an empty string', () {
      // FOUR OF SIX LIVE UNITS, Sterling Point among them. Null is what lets
      // the screen omit the card rather than draw an empty one.
      expect(unitWith(const {}).description, isNull);
    });

    test('fields present but blank are the same as absent', () {
      expect(
        unitWith({
          'longDescription': '',
          'shortDescription': '   ',
          'alternateLongDescription': '',
          'alternateShortDescription': '',
          'tinyDescription': '',
        }).description,
        isNull,
      );
    });

    test('a blank longer field does not block a filled shorter one', () {
      // The failure this guards: taking longDescription because the KEY is
      // present, and showing a blank paragraph while the short one had text.
      expect(
        unitWith({
          'longDescription': '   ',
          'shortDescription': _short,
        }).description,
        _short,
      );
    });
  });

  group('trimming', () {
    test('the returned text is trimmed, since it is rendered directly', () {
      expect(
        unitWith({'longDescription': '  $_long  '}).description,
        _long,
      );
    });
  });
}
