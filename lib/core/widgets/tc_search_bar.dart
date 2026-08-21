import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The mockup's grey rounded search field ("Search classrooms…",
/// "Search students…"). Pure presentation: state stays with the caller.
class TcSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  const TcSearchBar({
    super.key,
    required this.hint,
    this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44.h,
      decoration: BoxDecoration(
        color: AppColors.searchFill,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTypography.inputText,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.textTertiary, size: 20.r),
          hintText: hint,
          hintStyle:
              AppTypography.inputText.copyWith(color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
