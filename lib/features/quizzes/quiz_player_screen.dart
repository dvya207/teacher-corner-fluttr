import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/assignment.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/tc_app_bar.dart';
import '../../core/widgets/tc_empty_state.dart';
import 'quiz_player_provider.dart';

/// Answering one quiz.
///
/// ONE QUESTION AT A TIME, which is what the small screen affords and what the
/// production app does. A single scrolling form of twenty questions with images
/// in the options is unusable on a phone.
class QuizPlayerScreen extends StatelessWidget {
  const QuizPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuizPlayerProvider>();

    if (provider.status == QuizPlayerStatus.submitted) {
      return _ResultScreen(provider: provider);
    }

    final question = provider.current;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TcAppBar(title: provider.assignment.displayName),
      body: question == null
          // A LIVE QUIZ WITH NO QUESTIONS IS REAL. Four of the quizzes in this
          // database had none until recently, and an empty player with no
          // explanation looks like a failed load.
          ? TcEmptyState(
              icon: Icons.quiz_outlined,
              title: 'quizzes.no_questions_title'.tr(),
              subtitle: 'quizzes.no_questions_subtitle'.tr(),
            )
          : Column(
              children: [
                _Progress(provider: provider),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: _QuestionBody(
                      provider: provider,
                      question: question,
                    ),
                  ),
                ),
                _Footer(provider: provider),
              ],
            ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.provider});

  final QuizPlayerProvider provider;

  @override
  Widget build(BuildContext context) {
    final total = provider.questions.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${provider.index + 1} / $total',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'quizzes.answered'.tr(
                  args: ['${provider.answeredCount}', '$total'],
                ),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : (provider.index + 1) / total,
              minHeight: 4,
              backgroundColor: AppColors.borderLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionBody extends StatelessWidget {
  const _QuestionBody({required this.provider, required this.question});

  final QuizPlayerProvider provider;
  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          // THE TITLE IS HTML from a rich-text editor. Rendering it as markup
          // needs a package this app does not carry, so the tags are stripped
          // rather than shown raw — a question reading "<p>What is…" is worse
          // than one that has lost its bold.
          stripHtml(question.questionTitle),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'quizzes.marks'.tr(args: ['${question.maxMarks}']),
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (question.isMcq)
          _Options(provider: provider, question: question)
        else if (question.isText)
          _TextAnswer(provider: provider, question: question)
        else if (question.isBlanks)
          _Blanks(provider: provider, question: question)
        else
          // DESCRIPTIVE and anything unrecognised. Said plainly rather than
          // rendered as a blank card: the scorer gives it zero, and a reader
          // deserves to know the question is not answerable here.
          Text(
            'quizzes.unsupported_question'.tr(),
            style: TextStyle(color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({required this.provider, required this.question});

  final QuizPlayerProvider provider;
  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final chosen = provider.currentAnswer.chosen;

    return Column(
      children: [
        for (var at = 0; at < question.options.length; at++)
          _OptionTile(
            option: question.options[at],
            selected: chosen.contains(at),
            single: question.oneCorrectOption,
            onTap: () => provider.toggleOption(at),
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.single,
    required this.onTap,
  });

  final AssignmentOption option;
  final bool selected;
  final bool single;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.skyBlue.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.skyBlue : AppColors.borderLight,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                single
                    ? (selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked)
                    : (selected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank),
                color: selected ? AppColors.skyBlue : AppColors.textTertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: option.isImage && option.name.trim().isEmpty
                    // AN IMAGE OPTION'S PICTURE IS A STORAGE PATH, and resolving
                    // one costs a round trip that mints a fresh token each time.
                    // The path is named instead of loaded; wiring the image needs
                    // the same cache the evidence screen uses.
                    ? Text(
                        'quizzes.image_option'.tr(),
                        style: TextStyle(color: AppColors.textSecondary),
                      )
                    : Text(option.name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextAnswer extends StatefulWidget {
  const _TextAnswer({required this.provider, required this.question});

  final QuizPlayerProvider provider;
  final QuizQuestion question;

  @override
  State<_TextAnswer> createState() => _TextAnswerState();
}

class _TextAnswerState extends State<_TextAnswer> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.provider.currentAnswer.text,
  );

  @override
  void didUpdateWidget(covariant _TextAnswer old) {
    super.didUpdateWidget(old);

    // MOVING TO ANOTHER QUESTION REBUILDS THIS WIDGET WITH A DIFFERENT ANSWER.
    // Without this the previous question's text stays in the box, and the
    // teacher submits it against the wrong question.
    final text = widget.provider.currentAnswer.text;

    if (_controller.text != text) _controller.text = text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: 6,
      maxLength: widget.question.maxCharLength > 0
          ? widget.question.maxCharLength
          : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: 'quizzes.your_answer'.tr(),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onChanged: widget.provider.setText,
    );
  }
}

class _Blanks extends StatelessWidget {
  const _Blanks({required this.provider, required this.question});

  final QuizPlayerProvider provider;
  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final keys = question.blanks.keys.toList();

    return Column(
      children: [
        for (var at = 0; at < keys.length; at++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              key: ValueKey('${provider.index}-${keys[at]}'),
              initialValue: provider.currentAnswer.blanks[keys[at]] ?? '',
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                labelText: 'quizzes.blank'.tr(args: ['${at + 1}']),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) => provider.setBlank(keys[at], value),
            ),
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.provider});

  final QuizPlayerProvider provider;

  @override
  Widget build(BuildContext context) {
    final submitting = provider.status == QuizPlayerStatus.submitting;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            if (provider.errorKey != null) ...[
              Text(
                provider.errorKey!.tr(),
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (provider.hasPrevious)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: submitting ? null : provider.previous,
                      child: Text('quizzes.previous'.tr()),
                    ),
                  ),
                if (provider.hasPrevious) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: submitting
                        ? null
                        : (provider.hasNext ? provider.next : provider.submit),
                    child: submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            provider.hasNext
                                ? 'quizzes.next'.tr()
                                : 'common.submit'.tr(),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultScreen extends StatelessWidget {
  const _ResultScreen({required this.provider});

  final QuizPlayerProvider provider;

  @override
  Widget build(BuildContext context) {
    final result = provider.result;
    final score = result?.studentScore ?? provider.marks.studentScore;
    final max = result?.maxScore ?? provider.marks.maxScore;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TcAppBar(title: provider.assignment.displayName),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                size: 64,
                color: AppColors.success,
              ),
              const SizedBox(height: 16),
              Text(
                'quizzes.submitted'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                // TRIMS A TRAILING .0 so a whole number does not read as a
                // decimal. Blanks can genuinely score 0.67, so the fraction has
                // to survive where it exists.
                'quizzes.scored'.tr(args: [formatScore(score), '$max']),
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'quizzes.attempt_number'.tr(
                  args: ['${result?.attemptNumber ?? 1}'],
                ),
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('common.back'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Strips HTML tags and decodes the few entities a rich-text editor emits.
///
/// NOT A PARSER, and not trying to be. The titles come from Quill and carry
/// `<p>`, `<strong>` and `<img>`; showing the markup raw is worse than showing
/// the words without formatting, and pulling in an HTML renderer for a question
/// title is not worth the dependency.
String stripHtml(String html) {
  final text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");

  return text.trim();
}

/// `3` rather than `3.0`, but `0.67` kept.
String formatScore(double score) =>
    score == score.roundToDouble() ? '${score.round()}' : '$score';
