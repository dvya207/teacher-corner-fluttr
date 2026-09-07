import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/models/assignment.dart';
import '../../../core/models/form_question.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tc_button.dart';
import '../../../core/widgets/tc_empty_state.dart';
import '../../../core/widgets/tc_status_message.dart';

/// Saves a completed form. Returns false when the write failed.
typedef FormSubmitter = Future<bool> Function(Map<String, Object?> answers);

/// A feedback form inside a workflow step.
///
/// FILLED IN PLACE, not on a screen of its own, unlike the quiz. A quiz has a
/// clock, an attempt allowance and a score, all of which want a screen; a form
/// is three questions a teacher answers on the way out of a lesson, and sending
/// them somewhere else to do it loses the step they were on.
class FormPanel extends StatefulWidget {
  const FormPanel({
    super.key,
    required this.assignment,
    required this.onSubmit,
    this.existingAnswers,
    this.canSubmit = true,
  });

  final Assignment assignment;
  final FormSubmitter onSubmit;

  /// What was submitted before, if anything. Present, the form opens filled in
  /// and already marked as done.
  final Map<String, Object?>? existingAnswers;

  /// False when there is nowhere to write, e.g. the step was opened outside a
  /// classroom. The form still renders, so a teacher can read what is being
  /// asked, but says why it cannot be sent.
  final bool canSubmit;

  @override
  State<FormPanel> createState() => _FormPanelState();
}

class _FormPanelState extends State<FormPanel> {
  /// Keyed by question number, which is what the saved document uses. The array
  /// index would renumber every stored answer the moment a question is added.
  final Map<int, Object?> _answers = {};
  final Map<int, TextEditingController> _controllers = {};

  bool _submitting = false;
  bool _submitted = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAnswers;
    if (existing != null && existing.isNotEmpty) _submitted = true;
    for (final q in widget.assignment.formQuestions) {
      final saved = existing?['${q.number}'];
      // NORMALISED ON THE WAY IN for a checkbox group: Firestore hands back a
      // List<dynamic>, and storing that raw would compare and submit values this
      // question may no longer offer. See FormQuestion.chosenFrom.
      _answers[q.number] = q.kind == FormAnswerKind.multiChoice
          ? q.chosenFrom(saved)
          : saved;
      // A CONTROLLER ONLY WHERE ONE HOLDS THE ANSWER. A star rating stores an
      // int and a checkbox group stores a List, so neither has any text to own,
      // and giving them one would be an object per question that nothing reads.
      if (q.kind == FormAnswerKind.text || q.kind == FormAnswerKind.choice) {
        _controllers[q.number] = TextEditingController(
          text: saved is String ? saved : '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<FormQuestion> get _questions => widget.assignment.formQuestions;

  bool get _complete =>
      _questions.every((q) => q.isAnswered(_answers[q.number]));

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return TcEmptyState(
        icon: Icons.fact_check_outlined,
        title: 'lu.form_empty_title'.tr(),
        subtitle: 'lu.form_empty_subtitle'.tr(),
      );
    }

    final instructions = widget.assignment.instructions.trim();

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (instructions.isNotEmpty) ...[
            TcStatusBanner(type: TcMsgType.info, message: instructions),
            SizedBox(height: AppDimensions.spacing16),
          ],
          for (final q in _questions) ...[
            _QuestionCard(
              question: q,
              controller: _controllers[q.number],
              rating: _answers[q.number] is int
                  ? _answers[q.number]! as int
                  : 0,
              chosen: _answers[q.number],
              // Only after a failed submit. Marking every question red before
              // a teacher has tried to send anything reads as scolding.
              missing:
                  _showErrors && !q.isAnswered(_answers[q.number]),
              onChanged: (value) => setState(() => _answers[q.number] = value),
            ),
            SizedBox(height: AppDimensions.spacing12),
          ],
          SizedBox(height: AppDimensions.spacing8),
          if (!widget.canSubmit)
            TcStatusBanner(
              type: TcMsgType.info,
              message: 'lu.form_no_classroom'.tr(),
            )
          else
            TcButton(
              label: _submitted
                  ? 'lu.form_resubmit'.tr()
                  : 'lu.form_submit'.tr(),
              icon: Icons.check_rounded,
              isLoading: _submitting,
              onPressed: _submit,
            ),
          if (_submitted && !_submitting) ...[
            SizedBox(height: AppDimensions.spacing12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18.r,
                  color: AppColors.successGreen,
                ),
                SizedBox(width: AppDimensions.spacing8),
                Text(
                  'lu.form_submitted'.tr(),
                  style: AppTypography.label.copyWith(
                    color: AppColors.successGreen,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    // Answers are checked BEFORE the write, not rejected by it. A half-filled
    // form saved and then complained about is a teacher's work lost.
    if (!_complete) {
      setState(() => _showErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('lu.form_incomplete'.tr())),
      );
      return;
    }

    setState(() => _submitting = true);
    // ONE BRANCH PER ANSWER SHAPE, and a switch rather than a conditional so a
    // kind added later cannot fall into the string cast by default. It did: a
    // checkbox group's answer is a List, `as String?` threw inside this async
    // method, and the failure surfaced as a submit button that spun forever
    // rather than as an error, because `_submitting` was never cleared.
    final payload = <String, Object?>{
      for (final q in _questions)
        '${q.number}': switch (q.kind) {
          FormAnswerKind.starRating => _answers[q.number],
          // Normalised again on the way out, not just on the way in: what is
          // stored must be options this question still offers, in its order.
          FormAnswerKind.multiChoice => q.chosenFrom(_answers[q.number]),
          _ => (_answers[q.number] as String?)?.trim(),
        },
    };

    final ok = await widget.onSubmit(payload);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) _submitted = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (ok ? 'lu.form_saved' : 'lu.form_save_failed').tr(),
        ),
      ),
    );
  }
}

/// One numbered question and whatever it is answered with.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.controller,
    required this.rating,
    required this.chosen,
    required this.missing,
    required this.onChanged,
  });

  final FormQuestion question;
  final TextEditingController? controller;
  final int rating;

  /// The stored answer, for a kind that no controller can hold. Only the
  /// checkbox group reads it; a text answer lives in [controller] and a rating
  /// in [rating].
  final Object? chosen;
  final bool missing;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: missing ? AppColors.error : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24.r,
                height: 24.r,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.skyBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${question.number}',
                  style: AppTypography.tiny.copyWith(
                    color: AppColors.skyBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Text(
                  question.question,
                  style: AppTypography.bodyStrong,
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacing12),
          switch (question.kind) {
            FormAnswerKind.starRating => _Stars(
              value: rating,
              onChanged: (v) => onChanged(v),
            ),
            FormAnswerKind.choice => _Choices(
              options: question.options,
              selected: controller?.text ?? '',
              onChanged: (v) {
                controller?.text = v;
                onChanged(v);
              },
            ),
            FormAnswerKind.multiChoice => _MultiChoices(
              options: question.options,
              selected: question.chosenFrom(chosen),
              onChanged: onChanged,
            ),
            FormAnswerKind.text => TextField(
              controller: controller,
              onChanged: onChanged,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                hintText: (question.prompt?.trim().isNotEmpty ?? false)
                    ? question.prompt
                    : 'lu.form_answer_hint'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusInput,
                  ),
                ),
              ),
            ),
          },
        ],
      ),
    );
  }
}

/// Five stars. Zero means unanswered, which is why there is no way to set it
/// back to zero once a star is tapped: a teacher who has rated cannot un-rate
/// by accident, and re-tapping the same star is far more likely a mis-tap than
/// a retraction.
class _Stars extends StatelessWidget {
  const _Stars({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var star = 1; star <= 5; star++)
          IconButton(
            onPressed: () => onChanged(star),
            padding: EdgeInsets.symmetric(horizontal: 2.w),
            constraints: BoxConstraints(minWidth: 40.r, minHeight: 40.r),
            tooltip: '$star',
            icon: Icon(
              star <= value ? Icons.star_rounded : Icons.star_border_rounded,
              size: 30.r,
              color: star <= value
                  ? AppColors.warning
                  : AppColors.textTertiary,
            ),
          ),
      ],
    );
  }
}

/// Radio options, for a question whose author supplied a list.
/// Any number of the options, as checkboxes.
///
/// CHECKBOXES RATHER THAN A MULTI-SELECT CONTROL, for the same reason the single
/// choice is a radio group and not a dropdown: a teacher answers this in front of
/// a class, and every option being visible without a tap is what makes that
/// possible.
class _MultiChoices extends StatelessWidget {
  const _MultiChoices({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final List<String> selected;

  /// Handed the WHOLE new list rather than the option that changed, so the
  /// parent stores an answer rather than reconstructing one.
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in options)
          CheckboxListTile(
            value: selected.contains(option),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(option, style: AppTypography.bodyMedium),
            onChanged: (on) {
              final picked = {...selected};
              if (on ?? false) {
                picked.add(option);
              } else {
                picked.remove(option);
              }
              // REBUILT IN THE QUESTION'S OWN ORDER, not tick order, so the same
              // set of boxes always stores the same list.
              onChanged([
                for (final o in options)
                  if (picked.contains(o)) o,
              ]);
            },
          ),
      ],
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // RadioGroup, not the deprecated groupValue/onChanged pair on each tile.
    return RadioGroup<String>(
      groupValue: selected.isEmpty ? null : selected,
      onChanged: (v) => onChanged(v ?? ''),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            RadioListTile<String>(
              value: option,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(option, style: AppTypography.bodyMedium),
            ),
        ],
      ),
    );
  }
}
