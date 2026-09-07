import '../utils/safe_parse.dart';

/// How one question of a FORM assignment is answered.
enum FormAnswerKind {
  text,
  starRating,

  /// Pick exactly one, from `dropDown` and its two variants.
  choice,

  /// Pick any number, from `checkBoxGroup`. Its answer is a LIST, which is why
  /// it is a kind of its own rather than a flag on [choice]: every caller that
  /// reads an answer has to know whether it is holding one value or several.
  multiChoice,
}

/// One question on a feedback form.
///
/// A DIFFERENT SHAPE FROM A QUIZ QUESTION, which is why this is its own model
/// rather than a flag on [QuizQuestion]. A quiz question has options, a correct
/// answer and marks; a form question has none of those, because nothing about a
/// form is scored. Sharing one class would mean every quiz screen carrying
/// fields that are always null for half its instances.
class FormQuestion {
  const FormQuestion({
    required this.number,
    required this.question,
    this.kind = FormAnswerKind.text,
    this.prompt,
    this.options = const [],
  });

  /// Where the questions live on a FORM document. A QUIZ uses `questionsData`
  /// instead; see the note in `Assignment.fromMap`.
  static const String field = 'questions';

  /// `questionNumber` from the document, which is what a teacher is shown, not
  /// the array index. The two agree in live data and there is no reason to
  /// trust that they always will.
  final int number;

  final String question;
  final FormAnswerKind kind;

  /// Placeholder text for a written answer, where the author supplied one.
  final String? prompt;

  /// Choices, for a question that has them. Empty for text and ratings.
  final List<String> options;

  /// Whether an answer to this question counts as given.
  ///
  /// A RATING OF ZERO IS NOT AN ANSWER. Star ratings start unset, and zero is
  /// the value that means "untouched" rather than "worst".
  ///
  /// AN EMPTY LIST IS NOT AN ANSWER either, and that is the same rule: a
  /// checkbox group starts with nothing ticked, so "no options chosen" and
  /// "never touched" are one state and neither counts as answered.
  bool isAnswered(Object? answer) => switch (kind) {
    FormAnswerKind.starRating => answer is int && answer > 0,
    FormAnswerKind.multiChoice => answer is List && answer.isNotEmpty,
    _ => answer is String && answer.trim().isNotEmpty,
  };

  /// The options ticked on a multi-choice question, in the order this question
  /// asks them.
  ///
  /// REBUILT FROM [options] RATHER THAN RETURNED AS STORED, so two teachers who
  /// tick the same boxes save the same list and a saved answer reads back in the
  /// order it was asked. Anything stored that is no longer an option is dropped:
  /// a form can be edited after it has been answered, and showing a choice the
  /// question no longer offers is worse than showing one fewer.
  List<String> chosenFrom(Object? answer) {
    if (answer is! List) return const [];
    final picked = {
      for (final v in answer)
        if (v != null) '$v'.trim(),
    };
    return [
      for (final option in options)
        if (picked.contains(option)) option,
    ];
  }

  static FormAnswerKind _kindFrom(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.contains('star') || value.contains('rating')) {
      return FormAnswerKind.starRating;
    }
    // BEFORE THE SINGLE-CHOICE TEST, because 'multiselect' contains 'select'
    // and would otherwise be answered with a radio group that silently drops
    // every choice but the last.
    if (value.contains('check') || value.contains('multi')) {
      return FormAnswerKind.multiChoice;
    }
    if (value.contains('drop') || value.contains('choice') ||
        value.contains('radio') || value.contains('select')) {
      return FormAnswerKind.choice;
    }
    return FormAnswerKind.text;
  }

  /// Options arrive as ONE STRING, comma separated, not as an array. Empty in
  /// every live document so far, which is exactly why this is worth parsing
  /// defensively rather than assuming a list.
  static List<String> _optionsFrom(Object? raw) {
    if (raw is List) {
      return [
        for (final o in raw)
          if (o != null && '$o'.trim().isNotEmpty) '$o'.trim(),
      ];
    }
    if (raw is! String) return const [];
    return [
      for (final part in raw.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  static List<FormQuestion> listFrom(Object? raw, {String? docId}) {
    if (raw is! List) return const [];
    final parsed = <FormQuestion>[];
    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      if (entry is! Map) continue;
      final data = <String, dynamic>{
        for (final e in entry.entries) '${e.key}': e.value,
      };

      final text = SafeParse.asDisplayString(data['question']);
      // A question with no text cannot be asked. Dropped rather than rendered
      // as a numbered blank a teacher has to guess at.
      if (text == null || text.trim().isEmpty) continue;

      parsed.add(
        FormQuestion(
          number:
              SafeParse.asIntOrNull(
                data['questionNumber'],
                docId: docId,
                field: 'questions.questionNumber',
              ) ??
              i + 1,
          question: text.trim(),
          kind: _kindFrom(SafeParse.asDisplayString(data['questionType'])),
          prompt: SafeParse.asDisplayString(data['prompt']),
          options: _optionsFrom(data['dropDownOptions']),
        ),
      );
    }
    parsed.sort((a, b) => a.number.compareTo(b.number));
    return List.unmodifiable(parsed);
  }
}
