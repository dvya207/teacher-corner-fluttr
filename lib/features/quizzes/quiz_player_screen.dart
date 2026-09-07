import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/assignment.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/tc_empty_state.dart';
import 'quiz_player_provider.dart';

/// Answering one quiz.
///
/// THE LAYOUT FOLLOWS THE PRODUCTION ANDROID APP: a navy header carrying the
/// title, an answered count and a progress bar; the case-study material, where
/// the quiz has any; then a panel with numbered pills, a type badge, the
/// question and its answer control, and Prev / position / Next.
///
/// ONE QUESTION AT A TIME. A single scrolling form of twenty questions with
/// image options is unusable on a phone, and the pills give random access
/// without it.
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
      body: Column(
        children: [
          _Header(provider: provider),
          Expanded(
            child: question == null
                // A LIVE QUIZ WITH NO QUESTIONS IS REAL, and an empty panel with
                // no explanation reads as a failed load.
                ? TcEmptyState(
                    icon: Icons.quiz_outlined,
                    title: 'quizzes.no_questions_title'.tr(),
                    subtitle: 'quizzes.no_questions_subtitle'.tr(),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    children: [
                      if (provider.assignment.background != null) ...[
                        _BackgroundCard(
                          background: provider.assignment.background!,
                        ),
                        const SizedBox(height: 14),
                      ],
                      _QuestionPanel(provider: provider, question: question),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The navy bar: back, title, badge, answered count, percent, progress.
class _Header extends StatelessWidget {
  const _Header({required this.provider});

  final QuizPlayerProvider provider;

  @override
  Widget build(BuildContext context) {
    final total = provider.questions.length;
    final answered = provider.answeredCount;
    final fraction = total == 0 ? 0.0 : answered / total;

    return Material(
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'common.back'.tr(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.assignment.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (provider.assignment.author.trim().isNotEmpty)
                          Text(
                            provider.assignment.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Badge(
                    label: 'quizzes.type_quiz'.tr(),
                    background: Colors.white.withValues(alpha: 0.15),
                    foreground: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'quizzes.answered'.tr(args: ['$answered', '$total']),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${(fraction * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  // THE BAR TRACKS ANSWERS, NOT POSITION. Paging to the last
                  // question without answering anything is not progress.
                  value: fraction,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.skyBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// The case-study material above the questions, when the quiz carries one.
class _BackgroundCard extends StatelessWidget {
  const _BackgroundCard({required this.background});

  final AssignmentBackground background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: AppColors.skyBlue, width: 4),
          top: BorderSide(color: AppColors.borderLight),
          right: BorderSide(color: AppColors.borderLight),
          bottom: BorderSide(color: AppColors.borderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.article_outlined,
                size: 16,
                color: AppColors.skyBlue,
              ),
              const SizedBox(width: 6),
              Text(
                'quizzes.reading_material'.tr().toUpperCase(),
                style: const TextStyle(
                  color: AppColors.skyBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (background.title.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              background.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
          if (background.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              stripHtml(background.description),
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
          if (background.documents.isNotEmpty) ...[
            const SizedBox(height: 10),
            // NAMED, NOT OPENED. Each is a Storage path and opening one needs a
            // document viewer this app does not carry; saying how many there are
            // beats a button that does nothing.
            Text(
              'quizzes.attachments'.tr(
                args: ['${background.documents.length}'],
              ),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// The white panel: pills, badge, question, answer, footer.
class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({required this.provider, required this.question});

  final QuizPlayerProvider provider;
  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _Pills(provider: provider),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'quizzes.question_of'.tr(
                  args: [
                    '${provider.index + 1}',
                    '${provider.questions.length}',
                  ],
                ),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              _Badge(
                label: typeLabel(question.questionType),
                background: badgeTint(question.questionType),
                foreground: badgeInk(question.questionType),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _QuestionText(index: provider.index, question: question),
          const SizedBox(height: 14),
          if (question.isMcq)
            _Options(provider: provider, question: question)
          // DESCRIPTIVE IS WRITTEN TOO, not unanswerable. It scores zero because
          // somebody marks it afterwards; the box has to be here or the answer
          // can never be given.
          else if (question.isWritten)
            _TextAnswer(provider: provider, question: question)
          else if (question.isBlanks)
            _Blanks(provider: provider, question: question)
          else
            Text(
              'quizzes.unsupported_question'.tr(),
              style: TextStyle(color: AppColors.textSecondary),
            ),
          if (question.isDescriptive) ...[
            const SizedBox(height: 8),
            // SAID OUT LOUD, because the result screen will show this question
            // scoring nothing however well it is answered, and that looks like a
            // bug unless the reader was told.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 15,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'quizzes.marked_by_teacher'.tr(),
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          _Footer(provider: provider),
        ],
      ),
    );
  }
}

class _Pills extends StatelessWidget {
  const _Pills({required this.provider});

  final QuizPlayerProvider provider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: provider.questions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, at) {
          final current = at == provider.index;
          final answered = provider.isAnswered(at);

          return Semantics(
            selected: current,
            button: true,
            child: InkWell(
              onTap: () => provider.goTo(at),
              customBorder: const CircleBorder(),
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: current
                      ? AppColors.skyBlue
                      // ANSWERED IS TINTED, NOT TICKED. A tick would claim the
                      // answer is right; the scorer has not run and this player
                      // never reveals correctness mid-quiz.
                      : (answered
                            ? AppColors.skyBlue.withValues(alpha: 0.12)
                            : Colors.white),
                  border: Border.all(
                    color: current ? AppColors.skyBlue : AppColors.borderLight,
                    width: current ? 0 : 1,
                  ),
                ),
                child: Text(
                  '${at + 1}',
                  style: TextStyle(
                    color: current ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuestionText extends StatelessWidget {
  const _QuestionText({required this.index, required this.question});

  final int index;
  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.skyBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // THE TITLE IS QUILL HTML. Rendering it needs a package this
                  // app does not carry, so the tags are stripped: a question
                  // reading "<p>What is…" is worse than one without its bold.
                  stripHtml(question.questionTitle),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'quizzes.marks'.tr(args: ['${question.maxMarks}']),
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
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
            // A. B. C. D. — production letters them, and a letter is what a
            // teacher reads out to a class.
            letter: String.fromCharCode(65 + at),
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
    required this.letter,
    required this.option,
    required this.selected,
    required this.single,
    required this.onTap,
  });

  final String letter;
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.skyBlue.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.skyBlue : AppColors.borderLight,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                single
                    ? (selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked)
                    : (selected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank),
                size: 22,
                color: selected ? AppColors.skyBlue : AppColors.textTertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: option.isImage && option.name.trim().isEmpty
                    // AN IMAGE OPTION'S PICTURE IS A STORAGE PATH; resolving one
                    // mints a fresh token per call and needs the evidence
                    // screen's cache. Named rather than shown, for now.
                    ? Text(
                        'quizzes.image_option'.tr(),
                        style: TextStyle(color: AppColors.textSecondary),
                      )
                    : Text(
                        '$letter. ${option.name}',
                        style: const TextStyle(height: 1.3),
                      ),
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

  /// 400 WHERE THE QUESTION DOES NOT SAY. `maxCharLength` is absent on every
  /// question in this database, and an unbounded box invites an essay into a
  /// field the scorer marks purely on being non-empty.
  int get _limit =>
      widget.question.maxCharLength > 0 ? widget.question.maxCharLength : 400;

  @override
  void didUpdateWidget(covariant _TextAnswer old) {
    super.didUpdateWidget(old);

    // MOVING BETWEEN QUESTIONS REBUILDS THIS WITH A DIFFERENT ANSWER. Without
    // this the previous question's text stays in the box and gets submitted
    // against the wrong question.
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
      maxLines: widget.question.isDescriptive ? 8 : 5,
      maxLength: _limit,
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) =>
              Text(
                '$currentLength / ${maxLength ?? _limit}',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: 'quizzes.your_answer'.tr(),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
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
              // KEYED ON QUESTION AND BLANK so paging rebuilds the field with
              // the right initial value instead of keeping the previous one.
              key: ValueKey('${provider.index}-${keys[at]}'),
              initialValue: provider.currentAnswer.blanks[keys[at]] ?? '',
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                labelText: 'quizzes.blank'.tr(args: ['${at + 1}']),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight),
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
    final last = !provider.hasNext;

    return Column(
      children: [
        if (provider.errorKey != null) ...[
          Text(
            provider.errorKey!.tr(),
            style: const TextStyle(color: AppColors.error, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
        ],
        /*
         * THE LABELS MUST NOT WRAP.
         *
         * These were fixed-width boxes holding an icon and a word, and a label
         * even slightly too wide broke mid-word and stacked its letters down the
         * button. Three things stop that: the buttons size to their own content
         * instead of to a guessed width, the position sits in the Expanded
         * between them so it absorbs the slack, and every label is one line.
         */
        Row(
          children: [
            _NavButton(
              onPressed: (submitting || !provider.hasPrevious)
                  ? null
                  : provider.previous,
              icon: Icons.chevron_left,
              label: 'quizzes.previous'.tr(),
              leadingIcon: true,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${provider.index + 1} / ${provider.questions.length}',
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (last)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: FilledButton.icon(
                  onPressed: submitting ? null : provider.submit,
                  icon: submitting
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(
                    'common.submit'.tr(),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                ),
              )
            else
              _NavButton(
                onPressed: submitting ? null : provider.next,
                icon: Icons.chevron_right,
                label: 'quizzes.next'.tr(),
                leadingIcon: false,
              ),
          ],
        ),
      ],
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
      body: SafeArea(
        child: Center(
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
      ),
    );
  }
}

/// The badge label for a question type.
///
/// `TEXT` READS AS "SHORT TEXT", which is what production's badge says and what
/// the box actually is — a few sentences, not an essay.
String typeLabel(String questionType) {
  switch (questionType.toUpperCase()) {
    case 'MCQ':
      return 'MCQ';
    case 'TEXT':
      return 'quizzes.type_short_text'.tr();
    case 'FILL_IN_THE_BLANKS':
    case 'RICH_BLANKS':
      return 'quizzes.type_blanks'.tr();
    case 'DESCRIPTIVE':
      return 'quizzes.type_descriptive'.tr();
    default:
      return questionType;
  }
}

Color badgeTint(String questionType) => questionType.toUpperCase() == 'MCQ'
    ? AppColors.skyBlue.withValues(alpha: 0.12)
    : AppColors.warning.withValues(alpha: 0.15);

Color badgeInk(String questionType) =>
    questionType.toUpperCase() == 'MCQ' ? AppColors.skyBlue : AppColors.warning;

/// Strips HTML tags and the few entities a rich-text editor emits.
///
/// NOT A PARSER, and not trying to be. Titles come from Quill carrying `<p>`,
/// `<strong>` and `<img>`; showing markup raw is worse than showing the words
/// unformatted, and an HTML renderer is not worth the dependency for a title.
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

/// `3` rather than `3.0`, but `0.67` kept — blanks really can score a fraction.
String formatScore(double score) =>
    score == score.roundToDouble() ? '${score.round()}' : '$score';

/// Prev / Next, sized to their own label and never wrapped.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.leadingIcon,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  /// Prev puts its chevron before the word and Next after it: the direction is
  /// the affordance, so the icon has to follow the word for Next.
  final bool leadingIcon;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
    );
    final chevron = Icon(icon, size: 18);

    /*
     * BOUNDED, AND IT HAS TO BE.
     *
     * A Row hands its non-flex children an unbounded width, and an
     * OutlinedButton given one throws "BoxConstraints forces an infinite width"
     * during layout. Flutter caught that inside the list and rendered the whole
     * body BLANK — correct header, nothing beneath it, and not one line in
     * logcat. That is what "the quiz will not open" looked like.
     *
     * A maxWidth rather than a fixed width is the point: the button still
     * shrinks to its label, so nothing wraps, but the constraint is finite. The
     * fixed 104 this replaced is what made "Previous" break mid-word.
     */
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: OutlinedButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: leadingIcon
              ? [chevron, const SizedBox(width: 4), text]
              : [text, const SizedBox(width: 4), chevron],
        ),
      ),
    );
  }
}
