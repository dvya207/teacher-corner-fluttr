import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/form_question.dart';

/// Parsing a FORM assignment's questions, and the multi-select type in
/// particular.
///
/// `checkBoxGroup` IS THIS APP'S OWN TYPE, added beyond production's seven, and
/// the only form question whose answer is a LIST. Most of what is asserted here
/// is that difference: how the type is recognised, what counts as an answer, and
/// what happens to a stored pick the question no longer offers.
void main() {
  List<FormQuestion> parse(List<Object?> raw) =>
      FormQuestion.listFrom(raw, docId: 'form1');

  Map<String, Object?> q(
    String type, {
    int number = 1,
    String question = 'What got in the way?',
    Object? options,
  }) => {
    'questionType': type,
    'questionNumber': number,
    'question': question,
    'dropDownOptions': ?options,
  };

  group('the kind a stored questionType maps to', () {
    test('checkBoxGroup is multi-choice', () {
      expect(parse([q('checkBoxGroup')]).single.kind,
          FormAnswerKind.multiChoice);
    });

    /// MATCHED BEFORE THE SINGLE-CHOICE TEST, and this is why. 'multiSelect'
    /// contains 'select', which is one of the words that means a single choice,
    /// so an ordering slip here would render a multi-select as a radio group and
    /// silently keep only the last pick.
    test('anything naming check or multi is multi-choice, however spelled', () {
      for (final spelling in [
        'checkBoxGroup',
        'checkbox',
        'CheckBoxGroup',
        'multiSelect',
        'multiselect',
        ' checkBoxGroup ',
      ]) {
        expect(parse([q(spelling)]).single.kind, FormAnswerKind.multiChoice,
            reason: '$spelling should be multi-choice');
      }
    });

    test('a plain dropDown is still a single choice', () {
      expect(parse([q('dropDown')]).single.kind, FormAnswerKind.choice);
      expect(parse([q('dropDownDynamic')]).single.kind, FormAnswerKind.choice);
    });

    /// `radioGroup` NEEDED NO CHANGE HERE, and this test is what says so on
    /// purpose. It is the web app's other row-authored type, single-select, and
    /// it lands on [FormAnswerKind.choice] through the existing 'radio' match,
    /// which already renders a radio group. Pinned so a later edit to the
    /// matcher cannot quietly send it somewhere else.
    test('radioGroup is a single choice, via the existing radio match', () {
      expect(parse([q('radioGroup')]).single.kind, FormAnswerKind.choice);
      expect(parse([q('RadioGroup')]).single.kind, FormAnswerKind.choice);
    });

    /// THE ORDERING THAT MATTERS. 'radioGroup' must not reach the multi-choice
    /// branch and 'checkBoxGroup' must not reach the single-choice one, or a
    /// form silently collects the wrong number of answers.
    test('the two row types do not collide', () {
      expect(parse([q('checkBoxGroup')]).single.kind,
          FormAnswerKind.multiChoice);
      expect(parse([q('radioGroup')]).single.kind, FormAnswerKind.choice);
    });

    test('starRating and text are unchanged', () {
      expect(parse([q('starRating')]).single.kind, FormAnswerKind.starRating);
      expect(parse([q('text')]).single.kind, FormAnswerKind.text);
      expect(parse([q('textBox')]).single.kind, FormAnswerKind.text);
    });
  });

  group('options', () {
    /// ONE STRING, COMMA SEPARATED, which is how the collection stores them for
    /// `dropDown` too. The wizard writes the same field for both types.
    test('come from dropDownOptions, trimmed and without blanks', () {
      final parsed =
          parse([q('checkBoxGroup', options: 'Time, Materials , , Noise')])
              .single;

      expect(parsed.options, ['Time', 'Materials', 'Noise']);
    });

    test('are empty when the field is absent', () {
      expect(parse([q('checkBoxGroup')]).single.options, isEmpty);
    });

    /// AN ARRAY IS WHAT THE WEB WIZARD NOW WRITES for this type, because its
    /// options are authored one per row and a row may contain a comma. Read
    /// as-is rather than re-split, or storing the array would have bought
    /// nothing.
    test('come through whole when stored as an array', () {
      final parsed = parse([
        q('checkBoxGroup', options: [
          'Ran out of time, mostly',
          '  Materials  ',
          '',
        ]),
      ]).single;

      expect(parsed.options, ['Ran out of time, mostly', 'Materials']);
    });

    /// A `dropDown` STILL CARRIES THE STRING, and both shapes live in this one
    /// field. Splitting stays correct for it.
    test('a comma string is still split', () {
      expect(
        parse([q('dropDown', options: 'Yes, No ,Maybe')]).single.options,
        ['Yes', 'No', 'Maybe'],
      );
    });
  });

  group('what counts as an answer', () {
    final multi =
        parse([q('checkBoxGroup', options: 'Time,Materials,Noise')]).single;

    /// AN EMPTY LIST IS NOT AN ANSWER, the same rule a zero rating follows: a
    /// checkbox group opens with nothing ticked, so "none chosen" and "never
    /// touched" are one state.
    test('an empty list is not answered', () {
      expect(multi.isAnswered(const <String>[]), isFalse);
      expect(multi.isAnswered(null), isFalse);
    });

    test('one tick is answered', () {
      expect(multi.isAnswered(const ['Noise']), isTrue);
    });

    /// A STRING IS NOT AN ANSWER TO THIS KIND. A value of the wrong shape means
    /// something else wrote it, and treating it as answered would submit it.
    test('a bare string does not count', () {
      expect(multi.isAnswered('Noise'), isFalse);
    });
  });

  group('chosenFrom', () {
    final multi =
        parse([q('checkBoxGroup', options: 'Time,Materials,Noise')]).single;

    /// IN THE QUESTION'S OWN ORDER, not the order stored, so the same set of
    /// boxes always reads back as the same list and two answers can be compared.
    test('returns the picks in the order the question asks them', () {
      expect(multi.chosenFrom(const ['Noise', 'Time']), ['Time', 'Noise']);
    });

    /// A FORM CAN BE EDITED AFTER IT HAS BEEN ANSWERED. Showing a choice the
    /// question no longer offers is worse than showing one fewer.
    test('drops a stored pick that is no longer an option', () {
      expect(multi.chosenFrom(const ['Weather', 'Time']), ['Time']);
    });

    test('de-duplicates a value stored twice', () {
      expect(multi.chosenFrom(const ['Time', 'Time']), ['Time']);
    });

    test('is empty for anything that is not a list', () {
      expect(multi.chosenFrom('Time'), isEmpty);
      expect(multi.chosenFrom(null), isEmpty);
      expect(multi.chosenFrom(4), isEmpty);
    });

    test('tolerates non-string entries by comparing their text', () {
      final numbered =
          parse([q('checkBoxGroup', options: '1,2,3')]).single;

      expect(numbered.chosenFrom(const [2, 3]), ['2', '3']);
    });
  });
}
