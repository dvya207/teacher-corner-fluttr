import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_typography.dart';

class TcInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  /// Additive: digit-only and fixed-length fields (phone, OTP) need to
  /// constrain input at the keyboard rather than only complain afterwards.
  /// Left null, this widget behaves exactly as it did before.
  final List<TextInputFormatter>? inputFormatters;

  /// Additive: lets a caller stop `prefixIcon` from being padded out to the
  /// 48dp icon minimum, which is wrong for a short text prefix like a dial
  /// code. Null keeps Material's default.
  final BoxConstraints? prefixIconConstraints;

  const TcInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.inputFormatters,
    this.prefixIconConstraints,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTypography.label),
          SizedBox(height: 6.h),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: AppTypography.inputText,
          validator: validator,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            prefixIconConstraints: prefixIconConstraints,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
