import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// Six boxed digit slots, as in the approved mockup.
///
/// One real input, not six. The boxes are decoration painted from the
/// controller's value, and a single transparent [TextField] fills the row and
/// takes every keystroke. That matters for more than tidiness:
///
///  * SMS autofill delivers the whole code at once. Six separate fields have to
///    split it by hand and get the focus hops right; one field just receives it.
///  * Backspace across a boundary, paste, and the keyboard's own suggestion bar
///    all behave the way the platform intends.
///  * There is one value to validate, so the validator stays the plain
///    "six digits or not" check it was.
///
/// It is a [FormField] so `Form.validate()` reaches it and the error renders
/// underneath, which a bare [TextField] inside a [Stack] could not do.
class OtpCodeField extends FormField<String> {
  OtpCodeField({
    super.key,
    required this.controller,
    this.length = 6,
    super.validator,
    this.autofocus = true,
  }) : super(
          initialValue: controller.text,
          builder: (field) => _OtpCodeFieldBody(
            state: field,
            controller: controller,
            length: length,
            autofocus: autofocus,
          ),
        );

  final TextEditingController controller;
  final int length;
  final bool autofocus;
}

class _OtpCodeFieldBody extends StatelessWidget {
  const _OtpCodeFieldBody({
    required this.state,
    required this.controller,
    required this.length,
    required this.autofocus,
  });

  final FormFieldState<String> state;
  final TextEditingController controller;
  final int length;
  final bool autofocus;

  /// Design-spec box, scaled at build time.
  static const double _boxHeight = 60;

  @override
  Widget build(BuildContext context) {
    final height = _boxHeight.h;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              // Painted from the value; never takes a tap, so the field below
              // owns the whole row's hit area.
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => _boxes(value.text),
                  ),
                ),
              ),
              Positioned.fill(child: _invisibleInput()),
            ],
          ),
        ),
        if (state.hasError) ...[
          SizedBox(height: AppDimensions.spacing8),
          Text(
            state.errorText!,
            style: AppTypography.caption.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  Widget _boxes(String text) {
    return Row(
      children: [
        for (var i = 0; i < length; i++) ...[
          if (i > 0) SizedBox(width: AppDimensions.spacing8),
          Expanded(
            child: _DigitBox(
              digit: i < text.length ? text[i] : null,
              // The slot the next keystroke lands in reads as solid; the ones
              // beyond it stay dashed placeholders.
              isNext: i == text.length,
            ),
          ),
        ],
      ],
    );
  }

  /// Transparent text and no cursor: the boxes already show the digits, and a
  /// second set drawn by the field itself would double them up.
  Widget _invisibleInput() {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      expands: true,
      maxLines: null,
      minLines: null,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      showCursor: false,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: const [AutofillHints.oneTimeCode],
      style: const TextStyle(color: Colors.transparent),
      cursorColor: Colors.transparent,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(length),
      ],
      // Every border nulled explicitly, not just `border`. The app theme sets
      // an inputDecorationTheme, and `InputDecoration.collapsed` leaves the
      // focused/enabled variants to be inherited — which drew one sky-blue
      // rounded rect around the whole six-box row.
      decoration: const InputDecoration(
        // The app theme sets filled: true with a white fillColor, which painted
        // an opaque rectangle straight over all six boxes. The field has to
        // stay on top to receive taps, so it is the fill that goes.
        filled: false,
        fillColor: Colors.transparent,
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        counterText: '',
      ),
      // Keeps the FormField's value in step, so validate() sees what is typed.
      onChanged: state.didChange,
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({required this.digit, required this.isNext});

  final String? digit;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final radius = AppDimensions.radiusInput;
    final filled = digit != null;
    final solid = filled || isNext;

    final content = Center(
      child: Text(
        digit ?? '',
        style: AppTypography.heading3.copyWith(color: AppColors.navy),
      ),
    );

    if (solid) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: filled ? AppColors.skyBlue : AppColors.textTertiary,
            width: 1.5,
          ),
        ),
        child: content,
      );
    }

    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppColors.borderInput,
        radius: radius,
      ),
      child: content,
    );
  }
}

/// Dashed rounded rectangle. Flutter's [Border] cannot dash, and the mockup's
/// empty slots are dashed, so the outline is walked with [Path.computeMetrics]
/// and drawn in segments.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  // Dash rhythm, fixed by the mockup rather than configurable.
  static const double dash = 4;
  static const double gap = 3;
  static const double strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
